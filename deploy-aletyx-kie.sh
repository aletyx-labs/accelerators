#!/bin/bash
# deploy-aletyx-kie.sh - Master deployment script for Aletyx Enterprise Build of Apache KIE
# Author: Aletyx, Inc.
# Version: 2.0
# Description: Deploys all necessary components for a complete Apache KIE environment

# Display banner
echo "============================================================"
echo "  Aletyx Enterprise Build of Apache KIE X Deployment Sample"
echo "  Version: 10.0.0"
echo "============================================================"

# Default values
DEFAULT_NAMESPACE="kie-demo"
DEFAULT_SERVICE_NAME="hiring-approval"
DEFAULT_DOMAIN_NAME="example.com"
DEFAULT_KEYCLOAK_BASE_URL="keycloak.example.com"
DEFAULT_REGISTRY_URL="docker.example.com"
DEFAULT_IMAGE_PULL_POLICY="IfNotPresent"

# Initialize variables with defaults
NAMESPACE=${NAMESPACE:-$DEFAULT_NAMESPACE}
SERVICE_NAME=${SERVICE_NAME:-$DEFAULT_SERVICE_NAME}
DOMAIN_NAME=${DOMAIN_NAME:-$DEFAULT_DOMAIN_NAME}
KEYCLOAK_BASE_URL=${KEYCLOAK_BASE_URL:-$DEFAULT_KEYCLOAK_BASE_URL}
REGISTRY_URL=${REGISTRY_URL:-$DEFAULT_REGISTRY_URL}
IMAGE_PULL_POLICY=${IMAGE_PULL_POLICY:-$DEFAULT_IMAGE_PULL_POLICY}
DEBUG_MODE=${DEBUG_MODE:-false}

# Configuration file path
CONFIG_FILE="deploy.config"

# Create timestamp for this deployment
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DEPLOY_DIR="deployments/${SERVICE_NAME}_${TIMESTAMP}"

# Define helper variables
MGMT_CONSOLE_NAME="${SERVICE_NAME}-management-console"
APP_PART_OF="${SERVICE_NAME}-app"
REALM="jbpm-openshift"

# Function to display usage instructions
display_usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -n, --namespace     Kubernetes namespace (default: $DEFAULT_NAMESPACE)"
  echo "  -s, --service-name  Application service name (default: $DEFAULT_SERVICE_NAME)"
  echo "  -d, --domain        Domain name for ingress (default: $DEFAULT_DOMAIN_NAME)"
  echo "  -k, --keycloak-url  Keycloak base URL (default: $DEFAULT_KEYCLOAK_BASE_URL)"
  echo "  -r, --registry-url  Container registry URL (default: $DEFAULT_REGISTRY_URL)"
  echo "  -u, --username      Registry/Keycloak username"
  echo "  -p, --password      Registry/Keycloak password"
  echo "  -c, --config        Path to config file (default: $CONFIG_FILE)"
  echo "  -b, --build         Build application before deployment"
  echo "  --image-pull-policy Set image pull policy (Always, IfNotPresent, Never)"
  echo "  --keycloak-admin    Keycloak admin username (for auth setup)"
  echo "  --keycloak-pass     Keycloak admin password (for auth setup)"
  echo "  --skip-keycloak     Skip Keycloak setup"
  echo "  --skip-postgres     Skip PostgreSQL setup"
  echo "  --debug             Enable debug mode for verbose output"
  echo "  --image             Specify custom image to use (overrides default)"
  echo "  -h, --help          Display this help message"
  echo ""
  echo "Example:"
  echo "  $0 --namespace my-project --service-name loan-approval --build"
  echo ""
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -n|--namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -s|--service-name)
      SERVICE_NAME="$2"
      shift 2
      ;;
    -d|--domain)
      DOMAIN_NAME="$2"
      shift 2
      ;;
    -k|--keycloak-url)
      KEYCLOAK_BASE_URL="$2"
      shift 2
      ;;
    -r|--registry-url)
      REGISTRY_URL="$2"
      shift 2
      ;;
    -u|--username)
      NEXUS_USERNAME="$2"
      shift 2
      ;;
    -p|--password)
      NEXUS_PASSWORD="$2"
      shift 2
      ;;
    -c|--config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    -b|--build)
      BUILD_APP=true
      shift
      ;;
    --image-pull-policy)
      IMAGE_PULL_POLICY="$2"
      shift 2
      ;;
    --keycloak-admin)
      ADMIN_USERNAME="$2"
      shift 2
      ;;
    --keycloak-pass)
      ADMIN_PASSWORD="$2"
      shift 2
      ;;
    --skip-keycloak)
      SKIP_KEYCLOAK=true
      shift
      ;;
    --skip-postgres)
      SKIP_POSTGRES=true
      shift
      ;;
    --debug)
      DEBUG_MODE=true
      shift
      ;;
    --image)
      CUSTOM_IMAGE="$2"
      shift 2
      ;;
    -h|--help)
      display_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      display_usage
      exit 1
      ;;
  esac
done

# Enable debug mode if requested
if [ "$DEBUG_MODE" = "true" ]; then
  set -x
  echo "Debug mode enabled - all commands will be printed before execution"
fi

# Check if config file exists and source it
if [ -f "$CONFIG_FILE" ]; then
  echo "Loading configuration from $CONFIG_FILE..."
  source "$CONFIG_FILE"
else
  echo "No configuration file found at $CONFIG_FILE. Using defaults and command-line options."

  # Check if required variables are defined
  if [ -z "$NEXUS_USERNAME" ] || [ -z "$NEXUS_PASSWORD" ]; then
    echo "Warning: Registry credentials not provided. Docker push operations may fail."
  fi

  if [ "$SKIP_KEYCLOAK" != "true" ] && ([ -z "$ADMIN_USERNAME" ] || [ -z "$ADMIN_PASSWORD" ]); then
    echo "Warning: Keycloak admin credentials not provided. Keycloak configuration may fail."
  fi

  # Create config file with current settings
  echo "Creating configuration file at $CONFIG_FILE..."
  cat > "$CONFIG_FILE" << EOF
NAMESPACE=${NAMESPACE}
SERVICE_NAME=${SERVICE_NAME}
DOMAIN_NAME=${DOMAIN_NAME}
KEYCLOAK_BASE_URL=${KEYCLOAK_BASE_URL}
REGISTRY_URL=${REGISTRY_URL}
NEXUS_USERNAME=${NEXUS_USERNAME}
NEXUS_PASSWORD=${NEXUS_PASSWORD}
ADMIN_USERNAME=${ADMIN_USERNAME}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
IMAGE_PULL_POLICY=${IMAGE_PULL_POLICY}
EOF
fi

# Display current configuration
echo "Current configuration:"
echo "  Namespace: $NAMESPACE"
echo "  Service Name: $SERVICE_NAME"
echo "  Domain: $DOMAIN_NAME"
echo "  Keycloak URL: $KEYCLOAK_BASE_URL"
echo "  Registry URL: $REGISTRY_URL"
echo "  Image Pull Policy: $IMAGE_PULL_POLICY"
echo "  Build Application: ${BUILD_APP:-false}"
echo "  Skip Keycloak: ${SKIP_KEYCLOAK:-false}"
echo "  Skip PostgreSQL: ${SKIP_POSTGRES:-false}"
echo "  Deployment Timestamp: $TIMESTAMP"
echo "  Deployment Directory: $DEPLOY_DIR"
echo ""

# Confirm deployment
read -p "Do you want to proceed with deployment? (y/n): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
  echo "Deployment aborted."
  exit 0
fi

# Create deployments directory if it doesn't exist
mkdir -p "$DEPLOY_DIR"

# Function to log deployment actions
log_action() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$DEPLOY_DIR/deployment.log"
}

# Function to create namespace if it doesn't exist
ensure_namespace() {
  log_action "Ensuring namespace $NAMESPACE exists..."
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
}

# Function to create Docker registry credentials in Kubernetes
create_registry_credentials() {
  log_action "Creating Docker registry credentials in Kubernetes..."
  if [ -n "$NEXUS_USERNAME" ] && [ -n "$NEXUS_PASSWORD" ]; then
    kubectl -n "$NAMESPACE" create secret docker-registry registry-credentials \
      --docker-server="$REGISTRY_URL" \
      --docker-username="$NEXUS_USERNAME" \
      --docker-password="$NEXUS_PASSWORD" \
      --docker-email="admin@example.com" \
      --dry-run=client -o yaml | kubectl apply -f -
  else
    log_action "Warning: Registry credentials not provided. Skipping registry-credentials creation."
  fi
}

# Function to deploy PostgreSQL
deploy_postgresql() {
  if [ "$SKIP_POSTGRES" == "true" ]; then
    log_action "Skipping PostgreSQL deployment as requested."
    return
  fi

  local db_name="$SERVICE_NAME-postgresql"
  log_action "Deploying PostgreSQL database..."

  # Cleanup existing PostgreSQL resources
  log_action "Cleaning up any existing PostgreSQL resources..."
  kubectl delete deployment "$db_name" -n "$NAMESPACE" --ignore-not-found=true
  kubectl delete service "$db_name" -n "$NAMESPACE" --ignore-not-found=true
  kubectl delete pvc "$db_name-pvc" -n "$NAMESPACE" --ignore-not-found=true
  sleep 5  # Wait for resources to be deleted

  # Create PostgreSQL secrets
  kubectl create secret generic postgresql-credentials -n "$NAMESPACE" \
    --from-literal=database-name=kogito \
    --from-literal=database-user=kogito \
    --from-literal=database-password=kogito123 \
    --dry-run=client -o yaml | kubectl apply -f -

  # Apply PostgreSQL YAML
  log_action "Creating PostgreSQL deployment files..."
  cat > "$DEPLOY_DIR/postgres-deployment.yaml" << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $db_name-pvc
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $db_name
  namespace: $NAMESPACE
  labels:
    app: $db_name
    app.kubernetes.io/part-of: $APP_PART_OF
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $db_name
  template:
    metadata:
      labels:
        app: $db_name
    spec:
      containers:
      - name: postgresql
        image: postgres:16.1-alpine3.19
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "kogito"
        - name: POSTGRES_USER
          value: "kogito"
        - name: POSTGRES_PASSWORD
          value: "kogito123"
        - name: PGDATA
          value: "/var/lib/postgresql/data/pgdata"
        volumeMounts:
        - name: postgresql-data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgresql-data
        persistentVolumeClaim:
          claimName: $db_name-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: $db_name
  namespace: $NAMESPACE
spec:
  selector:
    app: $db_name
  ports:
  - port: 5432
    targetPort: 5432
EOF

  log_action "Applying PostgreSQL deployment..."
  kubectl apply -f "$DEPLOY_DIR/postgres-deployment.yaml"

  # Wait for PostgreSQL to be ready
  log_action "Waiting for PostgreSQL to be ready..."
  kubectl wait --for=condition=available deployment/"$db_name" --timeout=300s -n "$NAMESPACE" || true

  log_action "PostgreSQL deployment completed"
}

# Function to create secure ingress with TLS certificate
create_secure_ingress() {
  local service_name=$1
  local service_port=$2
  local host="${service_name}.${DOMAIN_NAME}"

  log_action "Creating secure ingress for $service_name (port $service_port) at $host"

  # Create the ingress YAML file
  cat > "$DEPLOY_DIR/$service_name-ingress.yaml" << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $service_name
  namespace: $NAMESPACE
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /\$1
spec:
  tls:
  - hosts:
    - $host
    secretName: $service_name-tls
  rules:
  - host: $host
    http:
      paths:
      - path: /(.*)
        pathType: Prefix
        backend:
          service:
            name: $service_name
            port:
              number: $service_port
EOF

  kubectl apply -f "$DEPLOY_DIR/$service_name-ingress.yaml"

  log_action "Secure ingress created for $service_name"
  log_action "Your service will be available at https://$host once the certificate is issued"
}

# Function to deploy application
deploy_application() {
  log_action "Deploying main application..."

  # Set the application image name
  APP_IMAGE="${REGISTRY_URL}/${NAMESPACE}/${SERVICE_NAME}:latest"
  log_action "Application will be deployed as: $APP_IMAGE"

  # Create application deployment YAML
  cat > "$DEPLOY_DIR/$SERVICE_NAME-deployment.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $SERVICE_NAME
  namespace: $NAMESPACE
  labels:
    app: $SERVICE_NAME
    app.kubernetes.io/part-of: $APP_PART_OF
    app.kubernetes.io/runtime: java
    deployment.timestamp: "$TIMESTAMP"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $SERVICE_NAME
  template:
    metadata:
      labels:
        app: $SERVICE_NAME
        deployment.timestamp: "$TIMESTAMP"
    spec:
      imagePullSecrets:
      - name: nexus-registry-secret
      containers:
      - name: $SERVICE_NAME
        image: $APP_IMAGE
        imagePullPolicy: $IMAGE_PULL_POLICY
        ports:
        - containerPort: 8080
        env:
        - name: POSTGRESQL_USER
          value: "kogito"
        - name: POSTGRESQL_PASSWORD
          value: "kogito123"
        - name: POSTGRESQL_DATABASE
          value: "kogito"
        - name: POSTGRESQL_SERVICE
          value: "$SERVICE_NAME-postgresql"
        - name: KOGITO_SERVICE_URL
          value: "https://$SERVICE_NAME.$DOMAIN_NAME"
        - name: KOGITO_JOBS_SERVICE_URL
          value: "https://$SERVICE_NAME.$DOMAIN_NAME"
        - name: KOGITO_DATAINDEX_HTTP_URL
          value: "https://$SERVICE_NAME.$DOMAIN_NAME"
        - name: QUARKUS_OIDC_ENABLED
          value: "false"
        - name: QUARKUS_OIDC_AUTH_SERVER_URL
          value: "https://${KEYCLOAK_BASE_URL}/auth/realms/$REALM"
        - name: QUARKUS_HTTP_CORS
          value: "true"
        - name: QUARKUS_HTTP_CORS_ORIGINS
          value: "*"
        - name: QUARKUS_HTTP_CORS_METHODS
          value: "GET,POST,PUT,PATCH,DELETE,OPTIONS"
        - name: QUARKUS_HTTP_CORS_HEADERS
          value: "accept,authorization,content-type,x-requested-with,x-forward-for,content-length,host,origin,referer,Access-Control-Request-Method,Access-Control-Request-Headers"
        - name: QUARKUS_HTTP_CORS_EXPOSED_HEADERS
          value: "Content-Disposition,Content-Type"
        - name: QUARKUS_HTTP_CORS_ACCESS_CONTROL_MAX_AGE
          value: "24H"
        - name: QUARKUS_HTTP_CORS_ACCESS_CONTROL_ALLOW_CREDENTIALS
          value: "true"
---
apiVersion: v1
kind: Service
metadata:
  name: $SERVICE_NAME
  namespace: $NAMESPACE
  labels:
    deployment.timestamp: "$TIMESTAMP"
spec:
  selector:
    app: $SERVICE_NAME
  ports:
  - port: 80
    targetPort: 8080
EOF

  log_action "Applying application deployment..."
  kubectl apply -f "$DEPLOY_DIR/$SERVICE_NAME-deployment.yaml"

  # Create secure ingress
  create_secure_ingress "$SERVICE_NAME" 80

  # Save deployment info to the directory
  log_action "Saving deployment info..."
  cat > "$DEPLOY_DIR/deployment-info.txt" << EOF
Deployment timestamp: $TIMESTAMP
Image: $APP_IMAGE
Namespace: $NAMESPACE
Service: $SERVICE_NAME
EOF

  # Also save a copy of the script configuration
  cp "$CONFIG_FILE" "$DEPLOY_DIR/deploy.config" 2>/dev/null || log_action "Warning: Could not copy config file to deployment directory"
}

# Function to deploy management console
deploy_management_console() {
  log_action "Deploying management console..."
  VERSION="main"

  # Create management console deployment YAML
  cat > "$DEPLOY_DIR/$MGMT_CONSOLE_NAME-deployment.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $MGMT_CONSOLE_NAME
  namespace: $NAMESPACE
  labels:
    app: $MGMT_CONSOLE_NAME
    app.kubernetes.io/part-of: $APP_PART_OF
    app.kubernetes.io/runtime: nodejs
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $MGMT_CONSOLE_NAME
  template:
    metadata:
      labels:
        app: $MGMT_CONSOLE_NAME
    spec:
      imagePullSecrets:
      - name: registry-credentials
      containers:
      - name: management-console
        image: aletyx-docker/management-console:$VERSION
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
        env:
        - name: RUNTIME_TOOLS_MANAGEMENT_CONSOLE_OIDC_CLIENT_CLIENT_ID
          value: "aletyx-management-console"
        - name: KOGITO_CONSOLES_KEYCLOAK_CLIENT_SECRET
          value: AsUpErSeCreTClIenTsecRET
---
apiVersion: v1
kind: Service
metadata:
  name: $MGMT_CONSOLE_NAME
  namespace: $NAMESPACE
spec:
  selector:
    app: $MGMT_CONSOLE_NAME
  ports:
  - port: 80
    targetPort: 8080
EOF

  kubectl apply -f "$DEPLOY_DIR/$MGMT_CONSOLE_NAME-deployment.yaml"

  # Create secure ingress
  create_secure_ingress "$MGMT_CONSOLE_NAME" 80
}

# Function to configure Keycloak
configure_keycloak() {
  if [ "$SKIP_KEYCLOAK" == "true" ]; then
    log_action "Skipping Keycloak configuration as requested."
    return
  fi

  if [ -z "$ADMIN_USERNAME" ] || [ -z "$ADMIN_PASSWORD" ]; then
    log_action "Keycloak admin credentials not provided. Skipping Keycloak configuration."
    return
  fi

  log_action "Configuring Keycloak..."

  # Save the Keycloak configuration script
  cat > "$DEPLOY_DIR/keycloak-config.sh" << 'EOF'
#!/bin/bash
# Source configuration
if [ -f deploy.config ]; then
    source deploy.config
else
    echo "Configuration file not found!"
    exit 1
fi

# Function to extract value from JSON response
extract_json_value() {
    local json="$1"
    local key="$2"
    echo "$json" | grep -o "\"$key\":[^,}]*" | cut -d':' -f2- | tr -d '"' | tr -d ' '
}

# Function to get Keycloak access token
get_token() {
    echo "Attempting to get token from: https://${KEYCLOAK_BASE_URL}/auth/realms/master/protocol/openid-connect/token"

    local token_response
    token_response=$(curl -s -k -X POST "https://${KEYCLOAK_BASE_URL}/auth/realms/master/protocol/openid-connect/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "username=${ADMIN_USERNAME}" \
      -d "password=${ADMIN_PASSWORD}" \
      -d "grant_type=password" \
      -d "client_id=admin-cli")

    TOKEN=$(extract_json_value "$token_response" "access_token")

    if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
        echo "Failed to obtain access token. Response:"
        echo "$token_response"
        exit 1
    fi

    echo "Successfully obtained access token"
}

# Function to check if realm exists and create if needed
setup_keycloak_realm() {
    local realm="$1"
    echo "Checking if realm $realm exists..."

    local realm_check
    realm_check=$(curl -s -k -X GET "https://${KEYCLOAK_BASE_URL}/auth/admin/realms/${realm}" \
      -H "Authorization: Bearer ${TOKEN}")

    if echo "$realm_check" | grep -q "error"; then
        echo "Creating realm $realm..."
        curl -s -k -X POST "https://${KEYCLOAK_BASE_URL}/auth/admin/realms" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{
                "realm": "'"${realm}"'",
                "enabled": true,
                "sslRequired": "external",
                "registrationAllowed": false,
                "loginWithEmailAllowed": true,
                "duplicateEmailsAllowed": false,
                "resetPasswordAllowed": true,
                "editUsernameAllowed": false,
                "bruteForceProtected": true
            }'
        echo "Realm created successfully"
    else
        echo "Realm $realm already exists"
    fi
}

# Function to create or update client
setup_client() {
    local realm="$1"
    local client_id="$2"
    local redirect_uri="$3"
    local is_public="${4:-true}"
    local client_secret="${5:-}"

    echo "Setting up client $client_id..."

    # Check if client exists
    local clients_response
    clients_response=$(curl -s -k -X GET "https://${KEYCLOAK_BASE_URL}/auth/admin/realms/${realm}/clients" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json")

    local client_internal_id
    client_internal_id=$(echo "$clients_response" | grep -o "{[^}]*\"clientId\":\"$client_id\"[^}]*}" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

    local payload='{
        "clientId": "'"${client_id}"'",
        "enabled": true,
        "publicClient": '"${is_public}"',
        "redirectUris": ["'"${redirect_uri}"'"],
        "webOrigins": ["+"]'

    if [ "$is_public" = "false" ] && [ -n "$client_secret" ]; then
        payload="${payload}"',"secret": "'"${client_secret}"'"'
    fi

    payload="${payload}"'}'

    if [ -z "$client_internal_id" ]; then
        echo "Creating new client $client_id..."
        curl -s -k -X POST "https://${KEYCLOAK_BASE_URL}/auth/admin/realms/${realm}/clients" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            -d "$payload"
    else
        echo "Updating existing client $client_id..."
        curl -s -k -X PUT "https://${KEYCLOAK_BASE_URL}/auth/admin/realms/${realm}/clients/${client_internal_id}" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            -d "$payload"
    fi
}

create_user() {
    local realm="$1"
    local username="jdoe"
    local password="jdoe"
    local firstname="John"
    local lastname="Doe"
    local email="jdoe@example.com"

    echo "Creating user $username in realm $realm..."

    # Create user with direct JSON string
    local user_payload='{
        "username": "'"$username"'",
        "enabled": true,
        "emailVerified": true,
        "firstName": "'"$firstname"'",
        "lastName": "'"$lastname"'",
        "email": "'"$email"'",
        "credentials": [{
            "type": "password",
            "value": "'"$password"'",
            "temporary": false
        }]
    }'

    # Create user
    local create_response
    create_response=$(curl -s -k -X POST "https://${KEYCLOAK_BASE_URL}/auth/admin/realms/${realm}/users" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$user_payload")

    if [ -n "$create_response" ] && echo "$create_response" | grep -q "error"; then
        echo "User might already exist, proceeding to get user ID"
    else
        echo "User $username created successfully"
    fi

    # Get user ID
    local user_response
    user_response=$(curl -s -k -X GET "https://${KEYCLOAK_BASE_URL}/auth/admin/realms/${realm}/users?username=$username" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json")

    local user_id
    user_id=$(echo "$user_response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -z "$user_id" ]; then
        echo "Failed to get user ID for $username"
        return 1
    fi

    echo "Found user ID: $user_id"

    # Array of roles to create and assign
    local roles=("HR" "IT" "user")

    # Create and assign roles
    for role in "${roles[@]}"; do
        echo "Setting up role: $role"

        # Create role if it doesn't exist
        local role_payload='{
            "name": "'"$role"'"
        }'

        curl -s -k -X POST "https://${KEYCLOAK_BASE_URL}/auth/admin/realms/${realm}/roles" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            -d "$role_payload" || true

        # Get role ID
        local role_response
        role_response=$(curl -s -k -X GET "https://${KEYCLOAK_BASE_URL}/auth/admin/realms/${realm}/roles/${role}" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json")

        local role_id
        role_id=$(echo "$role_response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

        if [ -n "$role_id" ]; then
            # Assign role to user
            local role_mapping_payload='[{
                "id": "'"$role_id"'",
                "name": "'"$role"'"
            }]'

            curl -s -k -X POST "https://${KEYCLOAK_BASE_URL}/auth/admin/realms/${realm}/users/${user_id}/role-mappings/realm" \
                -H "Authorization: Bearer ${TOKEN}" \
                -H "Content-Type: application/json" \
                -d "$role_mapping_payload"

            echo "Role $role assigned to user $username"
        else
            echo "Could not find role ID for $role"
        fi
    done
}

# Main execution
REALM="jbpm-openshift"
# Management console name
MGMT_CONSOLE_NAME="${SERVICE_NAME}-management-console"
# Define the application group name
APP_PART_OF="${SERVICE_NAME}-app"

# Configure Keycloak
echo "Configuring Keycloak..."
get_token
setup_keycloak_realm "$REALM"
create_user "$REALM"

# Setup clients
setup_client "$REALM" "management-console" "https://${MGMT_CONSOLE_NAME}.${DOMAIN_NAME}/*" false "fBd92XRwPlWDt4CSIIDHSxbcB1w0p3jm"
EOF

  # Make the script executable
  chmod +x "$DEPLOY_DIR/keycloak-config.sh"

  # Set up a local deploy.config for the keycloak script
  cat > "$DEPLOY_DIR/deploy.config" << EOF
NAMESPACE=${NAMESPACE}
SERVICE_NAME=${SERVICE_NAME}
DOMAIN_NAME=${DOMAIN_NAME}
KEYCLOAK_BASE_URL=${KEYCLOAK_BASE_URL}
REGISTRY_URL=${REGISTRY_URL}
NEXUS_USERNAME=${NEXUS_USERNAME}
NEXUS_PASSWORD=${NEXUS_PASSWORD}
ADMIN_USERNAME=${ADMIN_USERNAME}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
EOF

  # Run the script from the deployment directory
  (cd "$DEPLOY_DIR" && ./keycloak-config.sh) | tee -a "$DEPLOY_DIR/keycloak-config.log"
}

# Function to clean up old deployments
cleanup_old_deployments() {
  local keep_count=${1:-10}  # Default to keeping last 10 deployments
  log_action "Cleaning up old deployments (keeping last $keep_count)..."

  # List deployments by timestamp, newest first
  find deployments -mindepth 1 -maxdepth 1 -type d -name "${SERVICE_NAME}_*" | sort -r | tail -n +$((keep_count+1)) | while read -r dir; do
    log_action "Removing old deployment: $dir"
    rm -rf "$dir"
  done
}

# Function to create symlink to latest deployment
create_latest_symlink() {
  log_action "Creating symlink to latest deployment..."
  rm -f "deployments/latest" 2>/dev/null
  ln -sf "$DEPLOY_DIR" "deployments/latest"
}

# Function to summarize deployment
summarize_deployment() {
  log_action "Creating deployment summary..."

  # Save summary to deployment directory
  cat > "$DEPLOY_DIR/deployment-summary.txt" << EOF
============================================================
  Deployment Summary
============================================================
Timestamp: $(date '+%Y-%m-%d %H:%M:%S')
Namespace: $NAMESPACE
Service Name: $SERVICE_NAME
Image: $APP_IMAGE
Image Pull Policy: $IMAGE_PULL_POLICY
Domain: $DOMAIN_NAME
Keycloak URL: $KEYCLOAK_BASE_URL

Application URLs:
  - Swagger UI: https://${SERVICE_NAME}.${DOMAIN_NAME}/q/swagger-ui
  - Management Console: https://${MGMT_CONSOLE_NAME}.${DOMAIN_NAME}

Credentials:
  - Username: jdoe
  - Password: jdoe
============================================================
EOF

  # Display summary
  cat "$DEPLOY_DIR/deployment-summary.txt"
}

# Main execution
clear
echo "============================================================"
echo "  Starting deployment process..."
echo "============================================================"
log_action "Beginning deployment with timestamp: $TIMESTAMP"

# Ensure the namespace exists
ensure_namespace

# Create registry credentials
create_registry_credentials

# Deploy PostgreSQL if not skipped
deploy_postgresql

# Deploy the main application
deploy_application

# Deploy management console
deploy_management_console

# Configure Keycloak if not skipped
configure_keycloak

# Create symlink to latest deployment
create_latest_symlink

# Clean up old deployments (keep last 10)
cleanup_old_deployments 10

# Summarize deployment
summarize_deployment

log_action "Deployment process completed"
log_action "Deployment directory: $DEPLOY_DIR"
log_action "Log file: $DEPLOY_DIR/deployment.log"

# Quarkus Full Accelerator for Aletyx Build of Apache KIE Projects Deployed to Kubernetes

The Full Accelerator is for both decisions and workflows. The project follows a template for the Apache Maven pom.xml, README (this file), LICENSE, logo, and application.properties files.
Make changes as appropriate.

An Aletyx Build of Apache KIE project builds upon Quarkus, the Supersonic Subatomic Java Framework.
More information about Quarkus can be found at https://quarkus.io/.

## Deploying to Kubernetes

To deploy to Kubernetes you will need to update a few things on this repository.

### POM.XML Changes

Update the `kubernetes` profile in the pom.xml starting on Line 254. You will need to change the container-image.registry to point to your container image registry. If the group needs to be updated that is handled in this section too. The ${artifactId} currently is how the image will be produced, so based on the default template with no artifactId changes, it will be called `start-with-aletyx`.

```xml
<profile>
  <id>kubernetes</id>
  <properties>
    <quarkus.kubernetes.deploy>true</quarkus.kubernetes.deploy>
    <quarkus.kubernetes.deployment-target>kubernetes</quarkus.kubernetes.deployment-target>
    <quarkus.kubernetes.ingress.expose>true</quarkus.kubernetes.ingress.expose>
    <!-- Change to your Image Container Registry -->
    <quarkus.container-image.registry>your-container-registry.com</quarkus.container-image.registry>
    <!-- Change to your Image Group -->
    <quarkus.container-image.group>aletyx-labs</quarkus.container-image.group>
    <!-- Builds an Image based on Artifact ID for the Image Container Registry -->
    <quarkus.container-image.name>${artifactId}</quarkus.container-image.name>
    <quarkus.container-image.build>true</quarkus.container-image.build>
    <quarkus.container-image.username>admin</quarkus.container-image.username>
    <quarkus.container-image.insecure>true</quarkus.container-image.insecure>
  </properties>
</profile>
```

### Using GitHub Actions

This repository includes a pre-configured GitHub Actions workflow to deploy to Kubernetes. To use this workflow, you'll need to set up the following secrets in your GitHub repository:

1. Go to your repository settings
2. Navigate to Secrets and Variables > Actions
3. Add the following repository secrets:

| Secret Name               | Description                                  |
| ------------------------- | -------------------------------------------- |
| `NEXUS_USERNAME`          | Username for the Nexus container registry    |
| `NEXUS_PASSWORD`          | Password for the Nexus container registry    |
| `KUBECONFIG`              | Base64-encoded Kubernetes configuration file |
| `KEYCLOAK_ADMIN_PASSWORD` | Admin password for Keycloak                  |

#### Running the Workflow

The workflow can be triggered in two ways:

1. **Automatically** on push to the `main` branch
2. **Manually** via workflow dispatch with customizable inputs:
   - `namespace`: Your workshop namespace (defaults to `user-[your-github-username]`)
   - `service_name`: Your application name (defaults to `hiring-approval`)

When the workflow runs, it will:

1. Build the application with Maven
2. Push the container image to the specified registry
3. Deploy the application to Kubernetes
4. Configure Keycloak for authentication
5. Set up the necessary services and ingresses

After a successful deployment, the workflow will output URLs for:

- Swagger UI: `https://[service-name].[domain-name]/q/swagger-ui`
- Task Console: `https://[service-name]-task-console.[domain-name]`
- Management Console: `https://[service-name]-management-console.[domain-name]`

### Application Properties Configuration

The `application.properties` file already contains the necessary configurations for development and production environments. When deploying to Kubernetes, the following environment variables will be used:

- `POSTGRESQL_USER`: Database username (default: kogito)
- `POSTGRESQL_PASSWORD`: Database password (default: kogito123)
- `POSTGRESQL_DATABASE`: Database name (default: kogito)
- `POSTGRESQL_SERVICE`: PostgreSQL service name (auto-configured)
- `KOGITO_SERVICE_URL`: Service URL (auto-configured)
- `KOGITO_JOBS_SERVICE_URL`: Jobs service URL (auto-configured)
- `KOGITO_DATAINDEX_HTTP_URL`: Data index URL (auto-configured)

### Docker Configuration

The application is containerized using a standard Java 17 Alpine-based image. The Dockerfile configuration is handled automatically by the Quarkus Jib extension, but the effective configuration is:

```dockerfile
FROM eclipse-temurin:17-jre-alpine

# Set the working directory
WORKDIR /deployments

# Environment variables
ENV LANGUAGE='en_US:en'
ENV JAVA_OPTIONS="-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager"

# Copy the application jar and dependencies
COPY target/quarkus-app/lib/ /deployments/lib/
COPY target/quarkus-app/*.jar /deployments/
COPY target/quarkus-app/app/ /deployments/app/
COPY target/quarkus-app/quarkus/ /deployments/quarkus/

# Create a non-root user
RUN addgroup -S kogito && adduser -S kogito -G kogito \
	&& chown -R kogito:kogito /deployments

# Switch to non-root user
USER kogito

# Expose the application port
EXPOSE 8080

# Set the entrypoint
ENTRYPOINT [ "java", "-jar", "/deployments/quarkus-run.jar" ]
```

## Running the application in dev mode

Dev mode enables a number of helpful features while developing the project.
These include:

- Incremental compilation
- Live Reload both in the browser and Java code
- Automatic test execution
- Testcontainer startup for infrastructure
- OpenAPI specifications
- DevUI resources (https://quarkus.io/guides/dev-ui)
- Others depending on project capabilities

You can run your application in dev mode as follows:

```shell script
./mvnw compile quarkus:dev
```

> **_NOTE:_** DevUI is available at http://localhost:8080/q/dev/.

## Packaging and running the application

The application can be packaged using:

```shell script
./mvnw package
```

It produces the `quarkus-run.jar` file in the `target/quarkus-app/` directory.
Be aware that it's not an _über-jar_ as the dependencies are copied into the `target/quarkus-app/lib/` directory.

The application is now runnable using `java -jar target/quarkus-app/quarkus-run.jar`.

If you want to build an _über-jar_, execute the following command:

```shell script
./mvnw package -Dquarkus.package.type=uber-jar
```

The application, packaged as an _über-jar_, is now runnable using `java -jar target/*-runner.jar`.

## Creating a native executable

You can create a native executable using:

```shell script
./mvnw package -Dnative
```

Or, if you don't have GraalVM installed, you can run the native executable build in a container using:

```shell script
./mvnw package -Dnative -Dquarkus.native.container-build=true
```

You can then execute your native executable with: `./target/code-with-quarkus-1.0.0-SNAPSHOT-runner`

If you want to learn more about building native executables, please consult https://quarkus.io/guides/maven-tooling.

## Provided Code

The `src/main/resources/application.properties` file contains the basic properties for the project, enabling:

- CORS protection
- OpenAPI Specifications
- Swagger UI
- PostgreSQL setup

Add any additional code, Aletyx Build of Apache KIE resource files, and/or properties to their appropriate places following Apache Maven's standard project layout.

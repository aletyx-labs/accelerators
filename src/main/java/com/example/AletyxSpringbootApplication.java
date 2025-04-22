package com.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(scanBasePackages = { "org.kie.kogito.dmn.**", "org.kie.kogito.app.**", "http**" })
public class AletyxSpringbootApplication {

	public static void main(String[] args) {
		SpringApplication.run(AletyxSpringbootApplication.class, args);
	}
}

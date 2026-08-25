FROM registry.access.redhat.com/ubi9/openjdk-21:1.20-2.1727869871@sha256:1a2b3c4d5e6f7890abcdef1234567890abcdef1234567890abcdef1234567890 AS builder

WORKDIR /build
COPY . .
RUN ./mvnw -q -DskipTests package

FROM registry.access.redhat.com/ubi9/openjdk-21-runtime:1.20-2.1727869871@sha256:2b3c4d5e6f7890abcdef1234567890abcdef1234567890abcdef123456789012

WORKDIR /deployments
COPY --from=builder /build/target/*.jar app.jar
COPY bin/uid_entrypoint /usr/local/bin/uid_entrypoint
RUN chmod +x /usr/local/bin/uid_entrypoint

USER 1001
ENTRYPOINT ["/usr/local/bin/uid_entrypoint"]
CMD ["java", "-jar", "/deployments/app.jar"]

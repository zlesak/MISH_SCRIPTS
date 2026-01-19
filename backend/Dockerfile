FROM openjdk:26-ea-21-jdk-slim
WORKDIR /app
COPY app.jar .

# Import MongoDB certifikátu do Java truststore
COPY ca.pem /tmp/ca.pem
RUN keytool -importcert -trustcacerts -file /tmp/ca.pem \
    -alias mongo-tls \
    -keystore $JAVA_HOME/lib/security/cacerts \
    -storepass changeit -noprompt

ENV JAVA_OPTS="-Xmx512m -Xms256m"
HEALTHCHECK --interval=30s --timeout=30s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

RUN apt-get update && apt-get install -y curl
ENTRYPOINT ["java", "-jar", "app.jar"]
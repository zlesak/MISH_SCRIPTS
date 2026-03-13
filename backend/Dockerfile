FROM eclipse-temurin:21-jdk-jammy

WORKDIR /app
COPY app.jar .

# Import MongoDB certifikátu do Java truststore
COPY ca.pem /tmp/ca.pem
RUN keytool -importcert -trustcacerts -file /tmp/ca.pem \
    -alias mongo-tls \
    -keystore $JAVA_HOME/lib/security/cacerts \
    -storepass changeit -noprompt

RUN apt-get update && apt-get install -y curl

ENTRYPOINT ["java", "-jar", "app.jar"]

HEALTHCHECK --interval=10s --timeout=5s --retries=12 \
  CMD pgrep -f "Started MishApplicationKt" > /dev/null || exit 1
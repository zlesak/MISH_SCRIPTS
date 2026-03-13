# syntax=docker/dockerfile:1

FROM eclipse-temurin:17-jdk-jammy AS build
WORKDIR /src

COPY repo/ ./
RUN chmod +x gradlew
RUN ./gradlew clean bootJar -x test

FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

COPY --from=build /src/build/libs/*.jar app.jar

# Import MongoDB CA do Java truststore (TLS)
COPY ca.pem /tmp/ca.pem
RUN keytool -importcert -trustcacerts \
    -file /tmp/ca.pem \
    -alias mongo-tls \
    -keystore "$JAVA_HOME/lib/security/cacerts" \
    -storepass changeit \
    -noprompt \
  && rm -f /tmp/ca.pem

ENTRYPOINT ["java", "-jar", "app.jar"]

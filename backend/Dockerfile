FROM eclipse-temurin:17-jdk-jammy AS build
WORKDIR /src

COPY repo/gradlew ./
COPY repo/gradle ./gradle
COPY repo/settings.gradle.kts ./
COPY repo/build.gradle.kts ./
RUN chmod +x gradlew

RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew --no-daemon dependencies

COPY repo/src ./src
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew --no-daemon clean bootJar -x test

FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

COPY --from=build /src/build/libs/*.jar app.jar

COPY ca.pem /tmp/ca.pem
RUN keytool -importcert -trustcacerts \
    -file /tmp/ca.pem \
    -alias mongo-tls \
    -keystore "$JAVA_HOME/lib/security/cacerts" \
    -storepass changeit \
    -noprompt \
  && rm -f /tmp/ca.pem

ENTRYPOINT ["java", "-jar", "app.jar"]

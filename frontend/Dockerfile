FROM eclipse-temurin:21-jdk-jammy AS build
WORKDIR /src

COPY repo/mvnw ./
COPY repo/.mvn ./.mvn
COPY repo/pom.xml ./
RUN chmod +x mvnw

RUN --mount=type=cache,target=/root/.m2 \
    --mount=type=cache,target=/root/.vaadin \
    --mount=type=cache,target=/root/.npm \
    --mount=type=cache,target=/root/.pnpm-store \
    ./mvnw -B -DskipTests -Pproduction dependency:go-offline

COPY repo/ ./
RUN --mount=type=cache,target=/root/.m2 \
    --mount=type=cache,target=/root/.vaadin \
    --mount=type=cache,target=/root/.npm \
    --mount=type=cache,target=/root/.pnpm-store \
    ./mvnw -B clean package -DskipTests -Pproduction

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

COPY --from=build /src/target/*.jar app.jar

EXPOSE 8081
ENTRYPOINT ["java", "-jar", "app.jar"]

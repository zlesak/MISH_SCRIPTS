# syntax=docker/dockerfile:1

FROM eclipse-temurin:21-jdk-jammy AS build
WORKDIR /src

COPY repo/ ./
RUN chmod +x mvnw
RUN ./mvnw clean package -DskipTests -Pproduction

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

COPY --from=build /src/target/*.jar app.jar

EXPOSE 8081
ENTRYPOINT ["java", "-jar", "app.jar"]

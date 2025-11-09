FROM openjdk:26-ea-21-jdk-slim
WORKDIR /app
COPY app.jar .

ENV JAVA_OPTS="-Xmx512m -Xms256m"
HEALTHCHECK --interval=30s --timeout=30s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

RUN apt-get update && apt-get install -y curl
ENTRYPOINT ["java", "-jar", "app.jar"]
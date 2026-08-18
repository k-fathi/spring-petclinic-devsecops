FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

COPY ./target/*.jar /app.jar

EXPOSE 8080

RUN useradd -m -s /bin/nologin spring && chown -R spring:spring /app 

USER spring

CMD ["java", "-jar", "/app.jar"]
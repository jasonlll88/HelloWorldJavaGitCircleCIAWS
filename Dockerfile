FROM crsvr/java-build-image
MAINTAINER BdB <gmorris@bancodebogota.com.co>
#ARG JAR_VERSION
VOLUME /tmp
ADD target/app.jar app.jar
RUN bash -c 'touch /app.jar'
ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-jar","/app.jar"]

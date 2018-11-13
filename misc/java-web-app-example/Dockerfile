FROM registry.access.redhat.com/redhat-openjdk-18/openjdk18-openshift


COPY ./JavaHTTPServer.java .
COPY ./index.html .

WORKDIR .
RUN javac JavaHTTPServer.java
CMD ["java", "JavaHTTPServer"]

EXPOSE 8080
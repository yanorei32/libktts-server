docker build -t libktts-server .
docker run -p 3000:3000 -e MAXIMUM_LENGTH=140 -it libktts-server

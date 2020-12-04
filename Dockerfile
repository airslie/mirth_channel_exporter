#
# Build a docker image to let us launch the mirth_channel_exporter go binary,
# which scrapes the Mirth API for metrics (queue counts etc) and exposes this
# data at http://x.x.x.x/9141 so that for example prometheus can poll it and
# display the data in a grafana dashboard.
#
# To build
# docker login --username xxxx
# (if 2FA setup enter the token for your password)
# docker build -t airslie/mirth_channel_exporter:<version eg 0.2> .
# docker push airslie/mirth_channel_exporter:<version eg 0.2>
#

# First build the go binary using an intermediate image
FROM golang:1.15.6-buster as builder

# We don't need to specify a user but its good practice
ENV APP_USER app

# Map the app user's home dir to a suitable location, with acccess
ENV APP_HOME /go/src/mirth_channel_exporter
RUN groupadd $APP_USER && useradd -m -g $APP_USER -l $APP_USER
RUN mkdir -p $APP_HOME && chown -R $APP_USER:$APP_USER $APP_HOME
WORKDIR $APP_HOME
USER $APP_USER

# Copy the source into the work dir
COPY src/ .

# Download our go dependencies and build the binary
RUN go mod download
RUN go mod verify
RUN go build

# Now the build is done, create the final image (without the go installation).
# Hopefully we will end up with a smaller image this way, perhaps around 130MB.
FROM debian:buster

# Use the same user and home dir path, but this is not the same phsyical
# path used above - that is in the separate intermediate image.
ENV APP_USER app
ENV APP_HOME /go/src/mirth_channel_exporter
RUN groupadd $APP_USER && useradd -m -g $APP_USER -l $APP_USER
WORKDIR $APP_HOME

# Copy the compiled binary form the intermediate image (called 'builder')into
# this new image. # Change the owner to be the app user in this second image.
COPY --chown=0:0 --from=builder $APP_HOME/mirth_channel_exporter $APP_HOME

# We'll listen on this port
EXPOSE 9141

# Change the active user
USER $APP_USER

# The dafault command is to launch the go web app, listening on the above port.
# To configure mirth_channel_exporter settings, use a .env file in the
# local folder, or /etc/sysconfig/mirth_channel_exporter
# e.g.
# MIRTH_ENDPOINT=https://mirth-connect.yourcompane.com
# MIRTH_USERNAME=admin
# MIRTH_PASSWORD=admin
# See https://github.com/teamzerolabs/mirth_channel_exporter
CMD ["./mirth_channel_exporter"]

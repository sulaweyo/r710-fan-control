FROM alpine:latest
RUN apk add --no-cache ruby ipmitool lm-sensors
COPY Fan-Control-CLI.rb /opt/fancontrol/
COPY Fan_Control.rb /opt/fancontrol/
COPY fan-control.yaml /opt/fancontrol/
COPY Gemfile /opt/fancontrol/
RUN gem install bundler
RUN bundle install --gemfile=/opt/fancontrol/Gemfile
#ENTRYPOINT ["/opt/fancontrol/Fan-Control-CLI.rb start"]


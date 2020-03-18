FROM scratch
ADD sailfish.tar /
ARG LOCALUID
ENV LOCALUID ${LOCALUID}
RUN usermod -u $LOCALUID mersdk
# If you don't want to run full systemd, you can use something like:
# CMD ["/bin/bash", "/etc/mersdk/share/buildengine.sh"]
CMD ["/sbin/init"]

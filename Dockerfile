FROM scratch
ADD sailfish.tar /
ARG SDK_VERSION
LABEL SDK_VERSION=${SDK_VERSION}
ARG LOCALUID
ENV LOCALUID ${LOCALUID}
RUN ssh-keygen -A; \
    usermod -u $LOCALUID mersdk
# If you don't want to run full systemd, you can use something like:
# CMD ["/bin/bash", "/etc/mersdk/share/buildengine.sh"]
CMD ["/sbin/init"]

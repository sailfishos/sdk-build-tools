FROM scratch
ADD sailfish.tar /
ARG SDK_VERSION
LABEL SDK_VERSION=${SDK_VERSION}
ARG LOCALUID
ENV LOCALUID ${LOCALUID}
RUN env
RUN ssh-keygen -A
RUN usermod -u $LOCALUID mersdk
RUN rm /lib/systemd/system/sysinit.target.wants/*
RUN (cd /lib/systemd/system/multi-user.target.wants/; for i in *; do [ $i == sshd-keys.service ] || [ $i == sshd.socket ] || rm -f $i; done);
RUN rm /etc/systemd/system/basic.target.wants/*
RUN (cd /etc/systemd/system/multi-user.target.wants/; for i in *; do [ $i == sdk-webapp.service ] || rm -f $i; done);
RUN (cd /lib/systemd/system/sockets.target.wants/; for i in *; do [ $i == dbus.socket ] || rm -f $i; done);
RUN (cd /lib/systemd/system/basic.target.wants/; for i in *; do [ $i == dbus.service ] || rm -f $i; done);
# If you don't want to run full systemd, you can use something like:
# CMD ["/bin/bash", "/etc/mersdk/share/buildengine.sh"]
CMD ["/sbin/init"]

FROM registry.fedoraproject.org/f31/fedora-toolbox:31
LABEL com.coreos.toolbox=true
ADD build.sh /tmp
RUN /tmp/build.sh && rm -f /tmp/build.sh

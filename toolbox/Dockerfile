FROM registry.fedoraproject.org/f30/fedora-toolbox:30
LABEL com.coreos.toolbox=true
ADD build.sh /tmp
RUN /tmp/build.sh && rm -f /tmp/build.sh

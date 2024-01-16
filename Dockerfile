
ARG FROM_IMAGE
FROM $FROM_IMAGE

ENV OMPI_ALLOW_RUN_AS_ROOT=1
ENV OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1

# openmpi in docker issue
# https://github.com/open-mpi/ompi/issues/4948#issuecomment-395468231
# ENV OMPI_MCA_btl_vader_single_copy_mechanism=none

COPY run.sh /root
RUN chmod +x /root/run.sh && /root/run.sh && useradd -ms /bin/bash runner

# Dockerfile sourced from: 
# https://catalog.redhat.com/software/containers/rhel8/python-39/6065b20a0376735023221b11?container-tabs=dockerfile


# This image provides a Python 3.9 environment you can use to run your Python
# applications.
FROM ubi8/s2i-base:rhel8.5

EXPOSE 8080

ENV PYTHON_VERSION=3.9 \
    PATH=$HOME/.local/bin/:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=UTF-8 \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    CNB_STACK_ID=com.redhat.stacks.ubi8-python-39 \
    CNB_USER_ID=1001 \
    CNB_GROUP_ID=0 \
    PIP_NO_CACHE_DIR=off

# RHEL7 base images automatically set these envvars to run scl_enable. RHEl8
# images, however, don't as most images don't need SCLs any more. But we want
# to run it even on RHEL8, because we set the virtualenv environment as part of
# that script
ENV BASH_ENV=${APP_ROOT}/etc/scl_enable \
    ENV=${APP_ROOT}/etc/scl_enable \
    PROMPT_COMMAND=". ${APP_ROOT}/etc/scl_enable"

ENV SUMMARY="Platform for building and running Python $PYTHON_VERSION applications" \
    DESCRIPTION="Python $PYTHON_VERSION available as container is a base platform for \
building and running various Python $PYTHON_VERSION applications and frameworks. \
Python is an easy to learn, powerful programming language. It has efficient high-level \
data structures and a simple but effective approach to object-oriented programming. \
Python's elegant syntax and dynamic typing, together with its interpreted nature, \
make it an ideal language for scripting and rapid application development in many areas \
on most platforms."

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="Python 3.9" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,python,python39,python-39,rh-python39" \
      com.redhat.component="python-39-container" \
      name="ubi8/python-39" \
      version="1" \
      usage="s2i build https://github.com/sclorg/s2i-python-container.git --context-dir=3.9/test/setup-test-app/ ubi8/python-39 python-sample-app" \
      com.redhat.license_terms="https://www.redhat.com/en/about/red-hat-end-user-license-agreements#UBI" \
      io.buildpacks.stack.id="com.redhat.stacks.ubi8-python-39" \
      maintainer="SoftwareCollections.org <sclorg@redhat.com>"

RUN INSTALL_PKGS="python39 python39-devel python39-setuptools python39-pip nss_wrapper \
        httpd httpd-devel mod_ssl mod_auth_gssapi mod_ldap \
        mod_session atlas-devel gcc-gfortran libffi-devel libtool-ltdl enchant" && \
    yum -y module enable python39:3.9 httpd:2.4 && \
    yum -y --setopt=tsflags=nodocs install $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    # Remove redhat-logos-httpd (httpd dependency) to keep image size smaller.
    rpm -e --nodeps redhat-logos-httpd && \
    yum -y clean all --enablerepo='*'

# Copy the S2I scripts from the specific language image to $STI_SCRIPTS_PATH.
COPY 3.9/s2i/bin/ $STI_SCRIPTS_PATH

# Copy extra files to the image.
COPY 3.9/root/ /

# Python 3 only
# Yes, the directory below is already copied by the previous command.
# The problem here is that the wheels directory is copied as a symlink.
# Only if you specify symlink directly as a source, COPY copies all the
# files from the symlink destination.
COPY 3.9/root/opt/wheels /opt/wheels
# - Create a Python virtual environment for use by any application to avoid
#   potential conflicts with Python packages preinstalled in the main Python
#   installation.
# - In order to drop the root user, we have to make some directories world
#   writable as OpenShift default security model is to run the container
#   under random UID.
RUN \
    python3.9 -m venv ${APP_ROOT} && \
    # Python 3 only code, Python 2 installs pip from PyPI in the assemble script. \
    # We have to upgrade pip to a newer verison because: \
    # * pip < 9 does not support different packages' versions for Python 2/3 \
    # * pip < 19.3 does not support manylinux2014 wheels. Only manylinux2014 (and later) wheels \
    #   support platforms like ppc64le, aarch64 or armv7 \
    # We are newly using wheel from one of the latest stable Fedora releases (from RPM python-pip-wheel) \
    # because it's tested better then whatever version from PyPI and contains useful patches. \
    # We have to do it here (in the macro) so the permissions are correctly fixed and pip is able \
    # to reinstall itself in the next build phases in the assemble script if user wants the latest version \
    ${APP_ROOT}/bin/pip install /opt/wheels/pip-* && \
    rm -r /opt/wheels && \
    chown -R 1001:0 ${APP_ROOT} && \
    fix-permissions ${APP_ROOT} -P && \
    rpm-file-permissions

USER 1001

# Set the default CMD to print the usage of the language image.
CMD $STI_SCRIPTS_PATH/usage
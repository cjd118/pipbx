FROM debian:latest

#print commands in container
RUN set -x

RUN apt-get update && apt-get -y upgrade

#dependencies to install
RUN apt-get -y install curl \
    subversion

#asterix deps from install_deps script
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install binutils-dev \
    bison \
    build-essential \
    bzip2 \
    doxygen \
    flex \ 
    freetds-dev \
    graphviz \
    libasound2-dev \
    libbluetooth-dev \
    libc-client2007e-dev \
    libcap-dev \
    libcfg-dev \ 
    libcodec2-dev \
    libcorosync-common-dev \ 
    libcpg-dev \
    libcurl4-openssl-dev \
    libedit-dev \
    libfftw3-dev \
    libgmime-2.6-dev \ 
    libgmime-3.0-dev \ 
    libgsm1-dev \ 
    libical-dev \ 
    libiksemel-dev \ 
    libjack-jackd2-dev \
    libjansson-dev \
    libldap2-dev \
    liblua5.2-dev \
    libneon27-dev \
    libnewt-dev \
    libogg-dev \
    libosptk-dev \
    libpopt-dev \
    libpq-dev \
    libradcli-dev \
    libresample1-dev \
    libsndfile1-dev \
    libsnmp-dev \
    libspandsp-dev \
    libspeex-dev \
    libspeexdsp-dev \
    libsqlite3-dev \
    libsrtp2-dev \
    libssl-dev \
    libunbound-dev \
    liburiparser-dev \
    libvorbis-dev \
    libvpb-dev \
    libxml2-dev \
    libxslt1-dev \
    patch \
    pkg-config \
    portaudio19-dev \
    subversion \
    unixodbc-dev \
    uuid-dev \
    wget \
    xmlstarlet \
    zlib1g-dev

RUN mkdir -p /usr/src/asterisk

RUN curl -s https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-18-current.tar.gz | tar -zvxf - --strip-components=1 -C /usr/src/asterisk

#build asterix
WORKDIR /usr/src/asterisk

RUN ./contrib/scripts/get_mp3_source.sh

RUN ./configure

RUN make menuselect.makeopts

#mostly as taken from tiredofit/docker-freepbx
RUN menuselect/menuselect --disable BUILD_NATIVE \
    --enable-category MENUSELECT_APPS \
    --enable-category MENUSELECT_CHANNELS \
    --enable-category MENUSELECT_CODECS \
    --enable-category MENUSELECT_FORMATS \
    --enable-category MENUSELECT_FUNCS \
    --enable-category MENUSELECT_RES \
    --enable FORMAT_MP3 \
    --enable EXTRA-SOUNDS-EN-GSM \
    --enable BETTER_BACKTRACES \
    --disable MOH-OPSOUND-WAV \
    --enable MOH-OPSOUND-GSM \
    --disable app_voicemail_imap \
    --disable app_voicemail_odbc \
    --disable res_digium_phone 

RUN make install
RUN make install-headers
RUN make config
RUN ldconfig
RUN make install-logrotate

#not sure this will be wise long term but is useful for creating config files for now
RUN make samples

#create asterix user and group
RUN addgroup --gid 2600 asterisk
RUN adduser --uid 2600 --gid 2600 --gecos "Asterisk User" --disabled-password asterisk

#fix permission issues
RUN chown -R asterisk:asterisk /var/run/asterisk && \
    chown -R asterisk:asterisk /etc/asterisk && \
    chown -R asterisk:asterisk /var/lib/asterisk && \
    chown -R asterisk:asterisk /var/log/asterisk && \
    chown -R asterisk:asterisk /var/spool/asterisk && \
    chown -R asterisk:asterisk /var/run/asterisk && \
    chown -R asterisk:asterisk /usr/lib/asterisk && \
    touch /etc/asterisk/modules.conf && \
    touch /etc/asterisk/cdr.conf

###############################
# freepbx install
###############################

#php 5 package
RUN curl https://packages.sury.org/php/apt.gpg | apt-key add -
RUN echo "deb https://packages.sury.org/php/ buster main" > /etc/apt/sources.list.d/deb.sury.org.list

#node js
RUN curl --silent https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
RUN echo 'deb https://deb.nodesource.com/node_10.x buster main' > /etc/apt/sources.list.d/nodesource.list
RUN echo 'deb-src https://deb.nodesource.com/node_10.x buster main' >> /etc/apt/sources.list.d/nodesource.list

RUN apt-get update

#install freepbx dependencies
RUN apt-get -y install apache2 \
    cron \
    libmariadb-dev \
    mariadb-server \ 
    mariadb-client \
    nodejs \
    php5.6 \
    php5.6-curl \
    php5.6-cli \
    php5.6-mysql \
    php5.6-gd \
    php5.6-mbstring \
    php5.6-intl \
    php5.6-bcmath \
    php5.6-ldap \
    php5.6-xml \
    php5.6-zip \
    php5.6-sqlite3 \
    php-pear

#install odbc-mariadb from source
WORKDIR /usr/src
RUN mkdir -p mariadb-connector
RUN curl -sSL  https://downloads.mariadb.com/Connectors/odbc/connector-odbc-2.0.19/mariadb-connector-odbc-2.0.19-ga-debian-x86_64.tar.gz | tar xvfz - -C /usr/src/mariadb-connector
RUN mkdir -p /usr/lib/x86_64-linux-gnu/odbc/
RUN cp mariadb-connector/lib/libmaodbc.so /usr/lib/x86_64-linux-gnu/odbc/ 
RUN rm -rf mariadb-connector

# mariadb bind - from flaviostutz/freepbx, not sure of requirement?
RUN rm /etc/mysql/mariadb.conf.d/50-mysqld_safe.cnf
RUN sed -i 's/bind-address/#bind-address/' /etc/mysql/mariadb.conf.d/50-server.cnf

# add nodejs
RUN apt-get install -y nodejs

# odbc setup - think this is required?
ADD ./etc/odbc.ini /etc/
ADD ./etc/odbcinst.ini /etc/

#configure php and apache
RUN sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/5.6/apache2/php.ini
RUN sed -i 's/\(^memory_limit = \).*/\1256M/' /etc/php/5.6/apache2/php.ini
RUN sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf
RUN sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

RUN a2enmod rewrite
RUN a2enmod headers

#install freepbx
RUN mkdir -p /usr/src/freepbx
WORKDIR /usr/src/freepbx
RUN curl -s http://mirror.freepbx.org/modules/packages/freepbx/freepbx-15.0-latest.tgz | tar -zxvf -

WORKDIR /usr/src/freepbx/freepbx
RUN service mysql start && \
    ./start_asterisk start && \
    sleep 3 && \ 
    ./install -n && \
    fwconsole chown && \
    fwconsole ma upgradeall && \
    fwconsole ma downloadinstall backup bulkhandler ringgroups timeconditions ivr restapi cel configedit asteriskinfo certman ucp webrtc
    # fwconsole ma installall

#import gpg keys 
RUN gpg --refresh-keys --keyserver hkp://keyserver.ubuntu.com:80
RUN gpg --import /var/www/html/admin/libraries/BMO/9F9169F4B33B4659.key
RUN gpg --import /var/www/html/admin/libraries/BMO/3DDB2122FE6D84F7.key
RUN gpg --import /var/www/html/admin/libraries/BMO/86CE877469D2EAD9.key
RUN gpg --import /var/www/html/admin/libraries/BMO/1588A7366BD35B34.key

#needed?
RUN chown asterisk:asterisk -R /var/www/html

#clean up
RUN apt-get clean && apt-get autoremove -y


EXPOSE 80
#unsecure pjsip
EXPOSE 5060
#secure pjsip
EXPOSE 5061
#rtp
EXPOSE 11000-11010

RUN mkdir /scripts

ADD ./scripts /scripts
ADD ./etc/asterisk /etc/asterisk

CMD [ "/scripts/start.sh" ]



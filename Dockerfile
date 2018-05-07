FROM wordpress:4.9.5

USER root

ENV BACKUP_DIR /backups
VOLUME /backups

RUN apt-get update && apt-get install -y --no-install-recommends \
		cron mysql-client bzip2 wget\
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*
        

COPY scripts/restore.sh scripts/wait-for-it.sh /bin/

CMD ["/bin/bash","-c","/bin/wait-for-it.sh ${WORDPRESS_DB_HOST} -t 30 && apache2-foreground"]


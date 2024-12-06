FROM openjdk:21-jdk-slim-bookworm

# install tmux
RUN apt-get update && \
    apt-get install -y procps && \
    apt-get install -y strace && \
    apt-get install -y tmux && \
    apt-get install -y reptyr && \
    apt-get clean

RUN mkdir -p /root

COPY .tmux.conf /root/.tmux.conf
COPY .bashrc /root/.bashrc
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

RUN rm -f /minecraft/world/session.lock

WORKDIR /minecraft

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
#ENTRYPOINT ["sh", "-c", "tmux new-session -d -s minecraft '/minecraft/start.sh'; tail -f"]
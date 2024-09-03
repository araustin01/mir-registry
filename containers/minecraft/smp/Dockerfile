FROM openjdk:21-jdk-slim-bookworm

# install tmux
RUN apt-get update && \
    apt-get install -y tmux && \
    apt-get clean

RUN mkdir -p /root

COPY .tmux.conf /root/.tmux.conf
COPY .bashrc /root/.bashrc

WORKDIR /minecraft

ENTRYPOINT ["sh", "-c", "tmux new-session -d -s default ./start.sh; sleep 5 && tail -f ./logs/latest.log"]
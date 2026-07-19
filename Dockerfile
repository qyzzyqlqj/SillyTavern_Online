FROM node:20-bookworm


WORKDIR /app


RUN apt update && apt install -y \
    git \
    git-lfs \
    cron \
    gettext-base \
    && git lfs install



RUN git clone \
https://github.com/SillyTavern/SillyTavern.git



WORKDIR /app/SillyTavern


RUN npm install



WORKDIR /app


COPY start.sh .
COPY backup.sh .
COPY config.yaml .


RUN chmod +x start.sh backup.sh


EXPOSE 7860


CMD ["./start.sh"]
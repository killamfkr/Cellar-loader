FROM lscr.io/linuxserver/plex:latest

COPY plex_transcoder_wrapper.sh /opt/spore/plex_transcoder_wrapper.sh
COPY entrypoint.sh /opt/spore/entrypoint.sh
RUN chmod +x /opt/spore/entrypoint.sh /opt/spore/plex_transcoder_wrapper.sh

ENTRYPOINT ["/opt/spore/entrypoint.sh"]

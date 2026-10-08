FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/nginx.conf.template
COPY site/ /usr/share/nginx/html/

ENV PORT=8080
EXPOSE 8080

# nginx has no env-var interpolation in config, so substitute PORT at start.
CMD ["/bin/sh", "-c", "envsubst '$PORT' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf && exec nginx -g 'daemon off;'"]

from http.server import SimpleHTTPRequestHandler, HTTPServer
import logging
class Handler(SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        logging.info("%s - - %s" % (self.client_address[0], format%args))
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()

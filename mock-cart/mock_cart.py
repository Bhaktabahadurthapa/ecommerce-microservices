import grpc
from concurrent import futures
import time
import os

def serve():
    port = os.environ.get('PORT', '7070')
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=1))
    
    # Add a simple port binding without any actual service
    server.add_insecure_port(f'[::]:{port}')
    server.start()
    
    print(f"Mock Cart Service listening on port {port}")
    
    try:
        while True:
            time.sleep(86400)
    except KeyboardInterrupt:
        server.stop(0)

if __name__ == '__main__':
    serve()

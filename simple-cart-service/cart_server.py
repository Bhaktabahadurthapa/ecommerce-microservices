import grpc
from concurrent import futures
import time
import json
import redis
import os
import logging

# Import the generated protobuf classes
import demo_pb2
import demo_pb2_grpc

logging.basicConfig(level=logging.INFO)

class CartServiceServicer(demo_pb2_grpc.CartServiceServicer):
    def __init__(self):
        # Connect to Redis
        redis_addr = os.environ.get('REDIS_ADDR', 'redis:6379')
        redis_host = redis_addr.split(':')[0]
        redis_port = int(redis_addr.split(':')[1])
        self.redis_client = redis.Redis(host=redis_host, port=redis_port, decode_responses=True)
        logging.info(f"Connected to Redis at {redis_host}:{redis_port}")
        
    def AddItem(self, request, context):
        """Add an item to cart"""
        logging.info(f"AddItem called for user {request.user_id}, product {request.item.product_id}")
        
        user_id = request.user_id
        product_id = request.item.product_id
        quantity = request.item.quantity
        
        # Store cart in Redis
        cart_key = f"cart:{user_id}"
        existing_cart = self.redis_client.get(cart_key)
        
        if existing_cart:
            cart_items = json.loads(existing_cart)
        else:
            cart_items = []
            
        # Add or update item
        found = False
        for cart_item in cart_items:
            if cart_item['product_id'] == product_id:
                cart_item['quantity'] += quantity
                found = True
                break
                
        if not found:
            cart_items.append({
                'product_id': product_id,
                'quantity': quantity
            })
            
        self.redis_client.set(cart_key, json.dumps(cart_items))
        logging.info(f"Cart updated for user {user_id}: {cart_items}")
        
        return demo_pb2.Empty()
    
    def GetCart(self, request, context):
        """Get cart for user"""
        logging.info(f"GetCart called for user {request.user_id}")
        
        user_id = request.user_id
        cart_key = f"cart:{user_id}"
        
        cart_data = self.redis_client.get(cart_key)
        if cart_data:
            cart_items_data = json.loads(cart_data)
        else:
            cart_items_data = []
            
        # Create protobuf cart items
        cart_items = []
        for item_data in cart_items_data:
            cart_item = demo_pb2.CartItem(
                product_id=item_data['product_id'],
                quantity=item_data['quantity']
            )
            cart_items.append(cart_item)
            
        cart = demo_pb2.Cart(
            user_id=user_id,
            items=cart_items
        )
        
        logging.info(f"Returning cart for user {user_id} with {len(cart_items)} items")
        return cart
    
    def EmptyCart(self, request, context):
        """Empty cart for user"""
        logging.info(f"EmptyCart called for user {request.user_id}")
        
        user_id = request.user_id
        cart_key = f"cart:{user_id}"
        self.redis_client.delete(cart_key)
        
        return demo_pb2.Empty()

def serve():
    port = os.environ.get('PORT', '7070')
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    
    # Add the cart service to the server
    cart_servicer = CartServiceServicer()
    demo_pb2_grpc.add_CartServiceServicer_to_server(cart_servicer, server)
    
    server.add_insecure_port(f'[::]:{port}')
    server.start()
    
    logging.info(f"Cart Service started on port {port}")
    
    try:
        while True:
            time.sleep(86400)  # Sleep for a day
    except KeyboardInterrupt:
        server.stop(0)

if __name__ == '__main__':
    serve()

#!/usr/bin/env python3

import grpc
from concurrent import futures
import time
import json
import logging
import signal
import sys
import os

# Import the protobuf files from current directory
import demo_pb2
import demo_pb2_grpc

logging.basicConfig(level=logging.INFO)

class InMemoryCartService(demo_pb2_grpc.CartServiceServicer):
    def __init__(self):
        # Use in-memory storage for simplicity (no Redis dependency)
        self.carts = {}
        logging.info("Cart Service initialized with in-memory storage")
        
    def AddItem(self, request, context):
        """Add an item to cart"""
        logging.info(f"AddItem called for user {request.user_id}, product {request.item.product_id}")
        
        user_id = request.user_id
        product_id = request.item.product_id
        quantity = request.item.quantity
        
        # Get or create cart for user
        if user_id not in self.carts:
            self.carts[user_id] = []
        
        cart_items = self.carts[user_id]
        
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
        
        logging.info(f"Cart updated for user {user_id}: {cart_items}")
        return demo_pb2.Empty()
    
    def GetCart(self, request, context):
        """Get cart for user"""
        logging.info(f"GetCart called for user {request.user_id}")
        
        user_id = request.user_id
        cart_items_data = self.carts.get(user_id, [])
            
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
        self.carts[user_id] = []
        
        return demo_pb2.Empty()

def serve():
    port = 7072
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    
    # Add the cart service to the server
    cart_servicer = InMemoryCartService()
    demo_pb2_grpc.add_CartServiceServicer_to_server(cart_servicer, server)
    
    server.add_insecure_port(f'[::]:{port}')
    server.start()
    
    logging.info(f"Standalone Cart Service started on port {port}")
    
    def signal_handler(sig, frame):
        logging.info("Received interrupt signal. Shutting down...")
        server.stop(0)
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        while True:
            time.sleep(86400)  # Sleep for a day
    except KeyboardInterrupt:
        server.stop(0)

if __name__ == '__main__':
    serve()

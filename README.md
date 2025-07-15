# Microservices E-Commerce Application

A comprehensive microservices-based e-commerce application built with Docker Compose, featuring multiple services written in different programming languages.

## 🏗️ Architecture

This application follows a microservices architecture with the following services:

- **Frontend** (Go) - Web interface on port 8080
- **Product Catalog Service** (Go) - Product management on port 3550
- **Currency Service** (Node.js) - Currency conversion on port 7000
- **Shipping Service** (Go) - Shipping calculations on port 50051
- **Checkout Service** (Go) - Order processing on port 5050
- **Payment Service** (Node.js) - Payment processing on port 50052
- **Email Service** (Python) - Email notifications on port 5000
- **Redis** - Cache service on port 6379

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- At least 4GB of RAM available
- Ports 8080, 3550, 7000, 50051, 5050, 50052, 5000, 6379 available

### Running the Application

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd ecommerce
   ```

2. **Start all services:**
   ```bash
   docker compose up -d
   ```

3. **Access the application:**
   - Frontend: http://localhost:8080
   - View logs: `docker compose logs -f`
   - Check status: `docker compose ps`

4. **Stop the application:**
   ```bash
   docker compose down
   ```

   To also remove volumes (Redis data):
   ```bash
   docker compose down -v
   ```

## 📋 Available Commands

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f [service-name]

# Check service status
docker compose ps

# Scale a service
docker compose up -d --scale frontend=2

# Stop services
docker compose down

# Rebuild and start
docker compose up -d --build

# Remove everything including volumes
docker compose down -v --rmi all
```

## 🛠️ Development

### Project Structure

```
ecommerce/
├── docker-compose.yaml     # Service orchestration
├── Dockerfile             # Custom build configuration
├── .gitignore             # Git ignore rules
├── README.md              # This file
└── microservices-demo/    # Source code for all services
    └── src/
        ├── frontend/           # Go web interface
        ├── productcatalogservice/  # Go product service
        ├── currencyservice/    # Node.js currency service
        ├── shippingservice/    # Go shipping service
        ├── checkoutservice/    # Go checkout service
        ├── paymentservice/     # Node.js payment service
        └── emailservice/       # Python email service
```

### Technologies Used

- **Languages:** Go, Node.js, Python
- **Containerization:** Docker, Docker Compose
- **Database:** Redis (in-memory cache)
- **Architecture:** Microservices
- **Communication:** gRPC, HTTP

## 🐛 Troubleshooting

### Common Issues

1. **Slow build times on M1 Macs:**
   - First builds may take 5-10 minutes due to ARM64 compilation
   - Subsequent builds will be faster due to Docker layer caching

2. **Port conflicts:**
   - Ensure no other services are running on the required ports
   - Check with: `lsof -i :8080` (replace 8080 with the conflicting port)

3. **Memory issues:**
   - Increase Docker Desktop memory allocation to at least 4GB
   - Stop unnecessary Docker containers: `docker container prune`

4. **Build failures:**
   - Clean Docker cache: `docker system prune -a`
   - Restart Docker Desktop
   - Try building individual services: `docker compose build [service-name]`

### Viewing Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f frontend

# Last 50 lines
docker compose logs --tail=50
```

## 🔧 Configuration

### Environment Variables

The services communicate using the following environment variables (automatically configured):

- `PRODUCT_CATALOG_SERVICE_ADDR=productcatalogservice:3550`
- `CURRENCY_SERVICE_ADDR=currencyservice:7000`
- `CART_SERVICE_ADDR=cartservice:7070`
- `SHIPPING_SERVICE_ADDR=shippingservice:50051`
- `CHECKOUT_SERVICE_ADDR=checkoutservice:5050`
- `PAYMENT_SERVICE_ADDR=paymentservice:50051`
- `EMAIL_SERVICE_ADDR=emailservice:5000`

### Customization

To modify service configurations, edit the `compose.yaml` file:

- Add new environment variables
- Change port mappings
- Adjust resource limits
- Add health checks

## 📝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Test with `docker compose up -d`
5. Commit: `git commit -m "Add feature"`
6. Push: `git push origin feature-name`
7. Create a Pull Request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🙋‍♂️ Support

If you encounter any issues or have questions:

1. Check the [Troubleshooting](#-troubleshooting) section
2. View service logs: `docker compose logs -f`
3. Create an issue in this repository

---

Built with ❤️ using Docker and microservices architecture.

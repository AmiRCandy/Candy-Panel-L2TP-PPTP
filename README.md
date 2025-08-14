# 🍭 Candy Panel - L2TP/PPTP Management System

A simple, lightweight web interface for managing PPTP and L2TP VPN servers with a Lua-based backend.

## ✨ Features

  * **Beautiful UI**: A responsive web interface for managing clients.
  * **Client Management**: Create, edit, and delete L2TP/PPTP clients.
  * **Server Control**: Manage server settings and restart VPN services.
  * **Real-time Statistics**: Live bandwidth monitoring and server analytics (CPU, Memory).
  * **Automated Sync**: A background task automatically updates client traffic usage and deletes expired accounts.
  * **Installation Script**: A single `setup.sh` script handles the complete installation process.
  * **Responsive Design**: Works on desktop, tablet, and mobile browsers.

-----

## 🚀 Quick Start

### 🚀 One-line command install

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/AmiRCandy/Candy-Panel-L2TP-PPTP/main/setup.sh)"
```

  - Panel Default Port: 3446
  - API Default Port: 3446

### Prerequisites

  * **Nginx** with `lua-nginx-module` for the web server and backend.
  * **PPTP** and **L2TP/IPsec** services (`pptpd`, `strongswan`, `xl2tpd`).
  * **SQLite3** for the database.
  * **Git** for cloning the repository.

### Frontend & Backend Setup

The `setup.sh` script handles the full setup, including installing all dependencies and configuring Nginx. No manual steps are required for a quick start.

## 🏗️ Architecture

### Frontend Stack

  * **HTML, CSS, JavaScript**
  * **Bootstrap 5** for a responsive and modern design.
  * **Axios** for making API requests to the backend.

### Backend Stack

  * **OpenResty (Nginx with Lua)** for high-performance API handling.
  * **Lua** for the core backend logic.
  * **SQLite** for database management.
  * **System utilities** to interact with VPN services and server stats.

-----

## 🎯 Usage

### First Time Setup

The `setup.sh` script will automatically install everything you need. Once complete, you can access the panel at `http://<Your-Server-IP>:3446`.

### Managing Clients

1.  Navigate to the **Clients** page on the dashboard.
2.  Click **"Add New User"** to create a new client.
3.  Fill in the username, password, traffic limit, and expiration date.
4.  Use the **"Edit"** and **"Delete"** buttons to manage existing users.

### Server Configuration

You can view server stats like CPU, memory, and network usage directly from the dashboard.

-----

## 🔒 Security Features

  * **Database Management**: Client information is stored in a local SQLite database.
  * **IP Tables & UFW**: The setup script configures firewall rules to secure the VPN connections.
  * **Separation of concerns**: Frontend and backend are decoupled.

-----

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](https://www.google.com/search?q=CONTRIBUTING.md) for details.

1.  Fork the repository.
2.  Create a feature branch (`git checkout -b feature/your-feature`).
3.  Commit your changes (`git commit -m 'Add new feature'`).
4.  Push to the branch (`git push origin feature/your-feature`).
5.  Open a Pull Request.

-----

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](https://www.google.com/search?q=LICENSE) file for details.

-----

## 📞 Support

  * 📧 **Email**: amirhosen.1385.cmo@gmail.com
  * 🐛 **Issues**: [GitHub Issues](https://www.google.com/search?q=https://github.com/AmiRCandy/Candy-Panel-L2TP-PPTP/issues)

-----

<div align="center">
<p>Built with 💜 for L2TP/PPTP Enthusiasts</p>
<p>
<a href="[https://github.com/AmiRCandy/Candy-Panel-L2TP-PPTP/stargazers](https://www.google.com/search?q=https://github.com/AmiRCandy/Candy-Panel-L2TP-PPTP/stargazers)">⭐ Star us on GitHub</a> •
<a href="[https://github.com/AmiRCandy/Candy-Panel-L2TP-PPTP/issues](https://www.google.com/search?q=https://github.com/AmiRCandy/Candy-Panel-L2TP-PPTP/issues)">🐛 Report Bug</a> •
<a href="[https://github.com/AmiRCandy/Candy-Panel-L2TP-PPTP/issues](https://www.google.com/search?q=https://github.com/AmiRCandy/Candy-Panel-L2TP-PPTP/issues)">✨ Request Feature</a>
</p>
</div>
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "docker-desktop"
}

# 1. Namespace
resource "kubernetes_namespace" "app_ns" {
  metadata {
    name = "slack-bot-iac"
  }
}

# 2. Deployment
resource "kubernetes_deployment" "slack_bot" {
  metadata {
    name      = "slack-bot-deployment"
    namespace = kubernetes_namespace.app_ns.metadata[0].name
    labels = {
      app = "slack-bot"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "slack-bot"
      }
    }

    template {
      metadata {
        labels = {
          app = "slack-bot"
        }
      }

      spec {
        container {
          image = "slack-bot:latest"
          name  = "slack-bot-container"
          
          image_pull_policy = "Never" 

          port {
            container_port = 8000
          }
        }
      }
    }
  }
}

# 3. Service
resource "kubernetes_service" "slack_bot_service" {
  metadata {
    name      = "slack-bot-service"
    namespace = kubernetes_namespace.app_ns.metadata[0].name
  }
  spec {
    selector = {
      app = kubernetes_deployment.slack_bot.metadata[0].labels.app
    }
    port {
      port        = 8000
      target_port = 8000
    }
    type = "NodePort"
  }
}
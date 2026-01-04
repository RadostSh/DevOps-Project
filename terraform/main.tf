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

# Input
variable "slack_bot_token" {
  type = string
  sensitive = true
}
variable "slack_signing_secret" {
  type = string
  sensitive = true
}
variable "gemini_api_key" {
  type = string
  sensitive = true
}
variable "sashido_app_id" {
  type = string
  sensitive = true
}
variable "sashido_rest_key" {
  type = string
  sensitive = true
}
variable "sashido_api_url" {
  type = string
}

# Namespace
resource "kubernetes_namespace" "app_ns" {
  metadata {
    name = "slack-bot-iac"
  }
}

# Kubernetes Secret
resource "kubernetes_secret" "bot_secrets" {
  metadata {
    name = "slack-bot-secrets"
    namespace = kubernetes_namespace.app_ns.metadata[0].name
  }

  data = {
    SLACK_BOT_TOKEN = var.slack_bot_token
    SLACK_SIGNING_SECRET= var.slack_signing_secret
    GEMINI_API_KEY = var.gemini_api_key
    SASHIDO_APP_ID = var.sashido_app_id
    SASHIDO_REST_KEY = var.sashido_rest_key
    SASHIDO_API_URL = var.sashido_api_url
  }

  type = "Opaque"
}

# Deployment
resource "kubernetes_deployment" "slack_bot" {
  metadata {
    name = "slack-bot-deployment"
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
          name = "slack-bot-container"
          
          image_pull_policy = "Never" 

          port {
            container_port = 8000
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.bot_secrets.metadata[0].name
            }
          }
        }
      }
    }
  }
}

# Service
resource "kubernetes_service" "slack_bot_service" {
  metadata {
    name = "slack-bot-service"
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
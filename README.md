![image](https://github.com/firassaada/Leveraging-Terraform-and-AWS-for-Dynamic-Resource-Management/assets/94303698/5dccd0fb-8752-40ab-a438-4e9fd25d26e8)

# Automatisation du Déploiement et Redéploiement des Ressources AWS avec Terraform

## Description du Projet

Dans ce projet, nous avons créé un répertoire Git contenant deux branches, chacune comprenant un déploiement différent réalisé avec Terraform. La première branche déclenche le pipeline "CodePipeline2" qui utilise CodeBuild pour déployer l'infrastructure AWS avec Terraform. Le premier déploiement consiste en un serveur web hébergé sur une instance EC2 avec CloudWatch connecté à l'instance et surveillant la métrique "Utilisation du CPU". Lorsqu'un certain seuil est dépassé, une alarme est activée pour déclencher une fonction Lambda qui, à son tour, déclenche le "CodePipeline1".

Le "CodePipeline1" déploie ensuite la deuxième architecture pour le scaling, qui comprend : deux instances EC2 avec un équilibreur de charge pour gérer le trafic et une alarme CloudWatch liée aux deux instances. Cette alarme est déclenchée lorsque la métrique d'utilisation du CPU est en dessous d'un certain seuil. Cette alarme active une autre fonction Lambda qui déclenche "CodePipeline2" pour redéployer le premier déploiement, et le processus se répète. Ce système automatise le déploiement et le redéploiement des ressources AWS à des fins de scaling.

## Outils Utilisés

- Git
- Terraform
- AWS CodePipeline
- AWS CodeBuild
- AWS EC2
- AWS CloudWatch
- AWS Lambda
- Équilibrage de charge (Load Balancer)

## Mise en Œuvre

1. Création de deux branches dans le répertoire Git pour gérer les différents déploiements.
2. Déploiement initial d'un serveur web sur une instance EC2 via "CodePipeline2" et "CodeBuild".
3. Surveillance de l'instance EC2 avec CloudWatch et configuration d'une alarme basée sur l'utilisation du CPU.
4. Déclenchement d'une fonction Lambda lorsque l'alarme est activée pour lancer "CodePipeline1".
5. Déploiement d'une architecture de scaling avec deux instances EC2 et un équilibreur de charge via "CodePipeline1".
6. Surveillance des instances EC2 avec une autre alarme CloudWatch et configuration d'une alarme lorsque l'utilisation du CPU est en dessous du seuil défini.
7. Déclenchement d'une autre fonction Lambda pour lancer "CodePipeline2" et revenir au déploiement initial.
8. Répétition automatique du processus pour une gestion dynamique du scaling.

## Plan de Déploiement

1. Initialiser le répertoire Git et créer les deux branches nécessaires.
2. Configurer et déployer l'infrastructure initiale avec Terraform via "CodePipeline2".
3. Mettre en place CloudWatch pour surveiller les métriques d'utilisation du CPU et configurer les alarmes correspondantes.
4. Développer et déployer les fonctions Lambda pour automatiser le déclenchement des pipelines.
5. Configurer "CodePipeline1" pour déployer l'architecture de scaling et s'assurer que le tout est bien intégré.
6. Tester l'ensemble du processus pour vérifier que les déploiements et redéploiements se déroulent correctement selon les seuils d'utilisation du CPU.
7. Documenter le processus et fournir des instructions détaillées pour la gestion et la maintenance future du système.

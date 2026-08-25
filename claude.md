Desafio:

temos um repositorio chamado container-utils;
La os devs consomem os Dockerfiles, eles nao escrevem, apenas consomem, e banco.
Eles exigem que tenhamos um dispositivo que atualize isso pra eles, ou seja, eles
querem saber quais as ultimas versoes dispoveis das imagem sempre que houver uma release na main.

# Estrutura

├── README.md
├── SECURITY.md
├── microservices-deployment-dotnet10
│   ├── Dockerfile
│   └── bin
│       └── uid_entrypoint
├── microservices-deployment-dotnet6
│   ├── Dockerfile
│   └── bin
│       └── uid_entrypoint
├── microservices-deployment-dotnet8
│   ├── Dockerfile
│   └── bin
│       └── uid_entrypoint
├── microservices-deployment-openjdk11
│   ├── Dockerfile
│   └── bin
│       └── uid_entrypoint
├── microservices-deployment-openjdk17
│   ├── Dockerfile
│   └── bin
│       └── uid_entrypoint
├── microservices-deployment-openjdk21
│   ├── Dockerfile
│   └── bin
│       └── uid_entrypoint
├── python-deployment-3.12-slim
│   ├── Dockerfile
│   └── requirements.txt
├── react-deployment-nginx-with-envs
│   ├── Dockerfile
│   ├── build
│   ├── env.sh
│   └── nginx
│       ├── _.html
│       ├── default.conf
│       └── nginx.conf
├── react-deployment-nginx-with-envs-multipkg
│   ├── Dockerfile
│   ├── build
│   ├── env.sh
│   └── nginx
│       ├── _.html
│       ├── default.conf
│       └── nginx.conf
└── tibco-bwce-deployment
    └── Dockerfile

# Limitaçoes:

Webhook, nao vamos ter permissoes em tempo habil porque é Bank.
Pensei em um workflow, sistemas de release com uma action ou fazermos isso
Email pra todos os devs


Ajuda nesse aproche?


# REGRAS

- Criar um reamd.me explicativo pra um Analista Junior analisar e recriar
- Trabalhar com template githubactions , testado, validado e reproduzivel
- Criar fluxo com fluxo.md explicativo
- Validar que a outra equipa ( que seriam um grupo ou varios grupos de desenvolvedores), recebem ou conseguem ler o resultado com a info que eles querem.
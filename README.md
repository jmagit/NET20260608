# Curso de migración a SQL Server 2022 con EF Core 10

## Instalación

- [Visual Studio 2026](https://visualstudio.microsoft.com/es/downloads/) con las *cargas de trabajo* instaladas:
  - ASP.NET y desarrollo web
  - Almacenamiento y procesamiento de datos
- [SQL Server Management Studio](https://learn.microsoft.com/es-es/ssms/install/install) con los *componentes individuales* instalados:
  - Migración

## Opción con contenedores

### Subsistema de Windows para Linux (admin)

- [WSL 2 feature on Windows](https://learn.microsoft.com/es-es/windows/wsl/install)

#### Configuración de puertos dinámicos en Windows (admin)

```bash
netsh int ipv4 set dynamic tcp start=51000 num=14536
```

### Alternativas para el gestor contenedores (usar solo una)

- [Docker Desktop](https://www.docker.com/get-started/)
- [Podman](https://podman.io/docs/installation)
- [Rancher Desktop](https://rancherdesktop.io/)

### Contenedores

#### SQL Server 2022

    docker run -d -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=P@$$w0rd" -p 1433:1433 -v "%cd%":/var/opt/mssql/backup/ --workdir /var/opt/mssql/backup/ --name mssql2022 mcr.microsoft.com/mssql/server:2022-latest

#### SQL Server 2025

    docker run -d -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=P@$$w0rd" -p 1433:1433 -v "%cd%":/var/opt/mssql/backup/ --workdir /var/opt/mssql/backup/ --name mssql2025 mcr.microsoft.com/mssql/server:2025-latest

### Opción on-premises

- [SQL Server 2025 Developer](https://www.microsoft.com/es-es/sql-server/sql-server-downloads)

## Bases de datos de ejemplos

- [SQL Server Samples](https://github.com/microsoft/sql-server-samples/tree/master/samples/databases)


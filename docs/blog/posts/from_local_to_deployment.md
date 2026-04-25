---
date: 2026-04-25
authors:
  - zicong
categories:
  - Reflection
  - Engineering
---

# Navigating Environment Discrepancies: From Local Proxy Conflicts to Production Deployment

Recently, I was tasked with verifying the core functionalities of the AI4Careers platform, a full-stack project built utilizing the Jaclang framework. Following a series of significant updates to the backend architecture and database structure, my primary objectives were to ensure the resume parsing feature and the career fair data loading endpoints operated correctly. The process of testing these features across different environments revealed critical insights into system configuration and deployment practices specific to Jac server applications.

The initial testing phase took place in my local development environment, where I encountered an immediate failure with the resume upload function. The terminal output indicated that the underlying LiteLLM library was failing to communicate with the OpenAI API due to an unrecognized SOCKS proxy scheme on port 7897. I initially attempted to override this by modifying the .env file and using standard export commands in the terminal to set a standard HTTP proxy. These attempts failed because the active Conda virtual environment was persistently injecting system-level proxy variables that took precedence over my local configurations. To resolve this, I utilized the env -u command to systematically strip all lowercase and uppercase proxy variables from the runtime environment before launching the Jaclang server with a clean HTTP proxy. This approach successfully isolated the process and established the necessary network connection.

After verifying the logic locally, I shifted my focus to the production environment. Testing the live website revealed a different set of issues. Attempting to upload a resume resulted in a 500 Internal Server Error. By inspecting the network response payload in the browser's developer tools, I identified a ModuleNotFoundError specifically stating that the pypdf package was missing. The dependency was correctly listed in the requirements.txt file within the repository, indicating a gap in the deployment pipeline. The server had retrieved the latest codebase but the corresponding command to install the updated Python dependencies had not been executed in the production environment. 

A second issue emerged on the production career fair page, which displayed zero companies. Unlike the resume upload error, the network inspector showed that the API endpoints were returning a 200 OK status. This indicated that the backend code was executing without crashing and successfully querying the database. The root cause was that the newly configured production MongoDB instance had not been seeded with the initial dataset. While my local database retained its historical data, the production deployment process missed the crucial step of migrating or seeding the required company information into the new cloud database.

This debugging experience highlighted the complexities of managing full-stack applications. It demonstrated that successful code compilation does not guarantee functional parity across different environments. Identifying the distinction between network layer configurations, environment dependencies, and database states is essential for maintaining a reliable deployment pipeline.
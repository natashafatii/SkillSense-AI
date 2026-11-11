const roleSkillCatalog = <String, Map<String, String>>{
  'Languages': {
    'Popular programming languages':
        'Python|JavaScript|TypeScript|Java|C|C++|C#|Go|Rust|Swift|Kotlin|PHP|Ruby|Dart|R|Julia|'
        'Scala|Lua|Perl|Objective-C|Visual Basic .NET|F#|Elixir|Erlang|Clojure|Haskell|Groovy',
    'Web, markup & styling':
        'HTML|CSS|WebAssembly|WAT|Sass / SCSS|Less|Stylus|Elm|PureScript|ReScript|ReasonML|Haxe|'
        'CoffeeScript|XML|JSON|YAML|TOML|Markdown|LaTeX|Pug|Haml',
    'Systems & compiled languages':
        'Assembly|Zig|Nim|D|Ada|Fortran|COBOL|Pascal|Object Pascal / Delphi|V|Odin|Hare|Vala|'
        'Chapel|Pony|Carbon|Mojo|Crystal|Eiffel|Modula-2|Oberon|PL/I|BASIC|FreeBASIC|QBasic|'
        'ActionScript',
    'Scripting & automation languages':
        'Bash|Zsh|Fish shell|PowerShell|Windows Batch|Tcl|AWK|Sed|Nushell|AppleScript|AutoHotkey|'
        'AutoIt|VBScript|Nix|Make|Gnuplot|Expect|Rexx|Powershell DSC',
    'Functional, logic & academic languages':
        'OCaml|Standard ML|Common Lisp|Scheme|Racket|Smalltalk|Prolog|Datalog|Mercury|Idris|Agda|'
        'Lean|Coq / Gallina|Forth|Factor|Gleam|Unison|Clean|Curry|ATS|Janet|Hy|Carp|'
        'Purescript Halogen',
    'Data, query & scientific languages':
        'SQL|PL/SQL|T-SQL|PL/pgSQL|Cypher|SPARQL|GraphQL|DAX|Power Query M|SAS|Stata|MATLAB|'
        'GNU Octave|Wolfram Language|HiveQL|Pig Latin|jq|KQL (Kusto)|PromQL|Flux (InfluxDB)|IDL|'
        'Maple|Q (KDB+)|MDX',
    'Blockchain & emerging languages':
        'Solidity|Vyper|Move|Cairo|Cadence|Motoko|Clarity|Sway|Michelson|Pact|Scilla|Tact|FunC|Yul|'
        'Q#|Ballerina',
    'Enterprise, games & visual languages':
        'ABAP|Apex|RPG (IBM)|CL (IBM)|JCL|GDScript|GML (GameMaker)|Verse (Unreal)|UnrealScript|'
        'HLSL|GLSL|WGSL|ShaderLab|Processing|Scratch|Blockly|LabVIEW (G)|ColdFusion / CFML|Hack|'
        'FoxPro|MUMPS|OpenEdge ABL|Inform 7|4D|X++|Robot Framework syntax',
    'Hardware & embedded languages':
        'Verilog|SystemVerilog|VHDL|Chisel|Bluespec|SpinalHDL|QML|OpenSCAD|G-code|'
        'IEC 61131-3 Structured Text|Ladder Logic|Metal Shading Language|OpenCL C|CUDA C++|'
        'Arduino C++',
    'Configuration & domain-specific languages':
        'HCL|Bicep|CUE|Jsonnet|Dhall|Pkl|Starlark|Hjson|INI|Protocol Buffers|Apache Thrift IDL|'
        'XPath|XQuery|XSLT|Regular Expressions|Jinja2|Go Templates|Liquid|Handlebars|Graphviz DOT|'
        'TLA+|Modelica|AMPL|GAMS',
    'Classic & lesser-known languages':
        'Raku|APL|J|BQN|K|Roc|Fennel|Red|Rebol|AutoLISP|VBA|Visual Basic 6|xBase|Clipper|dBASE|'
        'Logo|SNOBOL|Icon|Icon / Unicon|Cython|Gambas|Io|Ring|Squirrel|AngelScript',
  },
  'Frontend': {
    'Frameworks & libraries':
        'React|Next.js|Vue.js|Nuxt|Angular|Svelte|SvelteKit|SolidJS|Qwik|Astro|Remix|Gatsby|Preact|'
        'Alpine.js|Ember.js|Backbone.js|Lit|HTMX|jQuery|Blazor|Electron|Tauri',
    'Styling & UI':
        'Tailwind CSS|Bootstrap|Material UI|Chakra UI|Ant Design|shadcn/ui|Radix UI|CSS Modules|'
        'Styled Components|Emotion|Storybook|Framer Motion|GSAP|Three.js|D3.js|Redux|Zustand|Pinia|'
        'MobX|TanStack Query',
    'Build tools & web platforms':
        'Vite|Webpack|Parcel|Rollup|Babel|ESLint|Prettier|npm|pnpm|Yarn|Bun|Accessibility (a11y)|'
        'Web Components|WebSockets|WebRTC|PWA|SEO',
  },
  'Backend': {
    'Frameworks':
        'Django|Django REST Framework|Flask|FastAPI|Express|Spring Boot|Laravel|NestJS|'
        'Ruby on Rails|ASP.NET Core|Koa|Hono|AdonisJS|Phoenix|Gin|Echo|Fiber|Chi|Actix Web|Axum|'
        'Rocket|Symfony|CodeIgniter|CakePHP|Micronaut|Quarkus|Ktor|Fastify',
    'Runtimes & API development':
        'Node.js|Deno|REST APIs|gRPC|OpenAPI / Swagger|OAuth 2.0|JWT|tRPC|Serverless Functions|'
        'Microservices|Webhooks|API Gateway|Socket.IO',
    'Messaging & background tasks':
        'Celery|Apache Kafka|RabbitMQ|Redis Streams|BullMQ|Apache Pulsar|NATS|gRPC Streams|'
        'Apache Camel',
  },
  'Mobile': {
    'Mobile frameworks & SDKs':
        'Flutter|React Native|Expo|SwiftUI|UIKit|Jetpack Compose|Android SDK|iOS SDK|Ionic|'
        'Capacitor|NativeScript|.NET MAUI|Xamarin|Kotlin Multiplatform|Compose Multiplatform|'
        'Cordova',
    'Mobile tools':
        'Android Studio|Xcode|Firebase Cloud Messaging|Fastlane|TestFlight|App Store Connect|'
        'Google Play Console',
  },
  'Data & AI': {
    'Data engineering & analytics':
        'Pandas|NumPy|Polars|Apache Spark|PySpark|dbt|Airflow|Dagster|Prefect|Kafka Streams|Flink|'
        'Hadoop|ETL / ELT|Power BI|Tableau|Looker|Metabase',
    'Machine learning & AI':
        'PyTorch|TensorFlow|Keras|scikit-learn|XGBoost|LightGBM|Hugging Face|Transformers|'
        'LangChain|LlamaIndex|OpenCV|spaCy|NLTK|JAX|MLflow|Weights & Biases|OpenAI API|RAG|'
        'Vector Search|MLOps',
    'Visualization & notebooks':
        'Jupyter|Google Colab|Matplotlib|Seaborn|Plotly|Streamlit|Gradio|Shiny',
  },
  'Databases': {
    'SQL databases':
        'PostgreSQL|MySQL|SQLite|MariaDB|Microsoft SQL Server|Oracle Database|CockroachDB|TiDB|'
        'Amazon Aurora|IBM Db2|Snowflake|BigQuery|Redshift|ClickHouse|DuckDB|Vertica',
    'NoSQL, cache & search':
        'MongoDB|Redis|Elasticsearch|OpenSearch|DynamoDB|Cassandra|ScyllaDB|CouchDB|Couchbase|'
        'Neo4j|ArangoDB|Firebase Firestore|Supabase|PlanetScale|Pinecone|Weaviate|Milvus|Qdrant|'
        'InfluxDB|TimescaleDB',
  },
  'DevOps': {
    'Cloud & hosting':
        'AWS|Google Cloud (GCP)|Microsoft Azure|Cloudflare|Vercel|Netlify|Render|Railway|'
        'DigitalOcean|Heroku|Fly.io|Firebase',
    'Infrastructure & deployment':
        'Docker|Kubernetes|Helm|Terraform|OpenTofu|Ansible|Pulumi|Packer|Nginx|Apache HTTP Server|'
        'Caddy|Traefik|Linux|Bash scripting|CI/CD|GitHub Actions|GitLab CI|Jenkins|CircleCI|'
        'Argo CD|FluxCD',
    'Observability & security':
        'Prometheus|Grafana|Datadog|New Relic|Sentry|OpenTelemetry|Jaeger|Vault|CloudWatch|'
        'ELK Stack|SonarQube|Snyk',
  },
  'Tools': {
    'Development & product tools':
        'Postman|Insomnia|Swagger UI|VS Code|IntelliJ IDEA|PyCharm|Vim|Neovim|Figma|Jira|Linear|'
        'Trello|Notion|Confluence|Slack',
    'Engineering & collaboration':
        'Agile|Scrum|Kanban|Technical Writing|System Design|Code Review|Architecture Diagrams|UML|'
        'Design Patterns|API Design',
    'Other platforms':
        'WordPress|Shopify|Salesforce|SAP|Unity|Unreal Engine|Godot|Blender',
  },
  'Testing': {
    'Automated testing':
        'Playwright|Cypress|Selenium|Puppeteer|Jest|Vitest|Mocha|Chai|Testing Library|JUnit|TestNG|'
        'pytest|unittest|Robot Framework|Appium|Detox|PHPUnit|RSpec',
    'Quality & performance':
        'TDD|BDD|End-to-End Testing|Integration Testing|Unit Testing|Contract Testing|'
        'Accessibility Testing|k6|JMeter|Lighthouse|Load Testing',
  },
  'Git': {
    'Version control & collaboration':
        'Git|GitHub|GitLab|Bitbucket|Azure Repos|Subversion (SVN)|Mercurial|Perforce|Git LFS',
  },
};

# Goodways IT Technical Hub

## Description

Welcome to the Goodways IT Technical Hub! This site serves as the official technical knowledge base and blog for the Goodways IT Team. We are a specialized technology consultancy focusing on Oracle Database and Oracle GoldenGate solutions. Our mission is to help organizations optimize their data infrastructure, ensure high availability, and streamline data integration processes using Oracle technologies.

This platform shares our expertise, insights, and details about our open-source contributions and professional services.

## Features

*   **In-depth Technical Articles**: Explore blog posts covering Oracle Database administration, Oracle GoldenGate, high availability, performance tuning, data migration, and more.
*   **Open Source Tools**: Learn about our suite of open-source tools designed for Oracle environments, including:
    *   `inspect4oracle`: Lightweight Oracle database health check tool.
    *   `adg-dashboard`: Professional Oracle Active Data Guard monitoring dashboard.
    *   `oracle-adgmgr`: Oracle Active Data Guard switchover management platform.
    *   `ggutil`: GoldenGate Classic edition multi-instance management tool.
*   **Professional Services**: Discover our range of services, including:
    *   Oracle Database Administration (setup, optimization, HA, monitoring).
    *   Oracle GoldenGate Solutions (architecture, implementation, tuning, support).
    *   Customization for our open-source tools.
*   **Search Functionality**: Easily find articles and information relevant to your needs.

## Local Development & Getting Started

To run this Jekyll site locally, you'll need to have Ruby and Bundler installed. This site is built to be compatible with GitHub Pages.

### Prerequisites

*   **Ruby**: Version `3.3.4` (as per [GitHub Pages dependency versions](https://pages.github.com/versions/))
    *   We recommend using a Ruby version manager like `rbenv` or `rvm` to manage Ruby versions.
*   **Bundler**: A Ruby gem to manage project dependencies. Install it with `gem install bundler`.

### Installation & Setup

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/goodwaysit/en.git
    cd en
    ```

2.  **Install dependencies:**
    Navigate to the `en` directory (or the root of your Jekyll project if it's structured differently) and run:
    ```bash
    bundle install
    ```
    This command will install Jekyll (version `3.10.0`) and other necessary gems as specified in the `Gemfile` and `Gemfile.lock`.

### Running the Site Locally

Once the dependencies are installed, you can serve the site locally:

```bash
bundle exec jekyll serve
```

By default, the site will be available at `http://localhost:4000`.

## Content Contribution (Blog Posts)

We welcome contributions and sharing of knowledge. If you wish to add a new blog post, please follow these guidelines:

1.  **Directory**: Create new Markdown files in the `_posts` directory.
2.  **Filename Format**: Use the `YYYY-MM-DD-your-post-title.md` format for filenames.
    *   Example: `2024-07-15-optimizing-oracle-performance.md`
3.  **Front Matter**: Ensure each post includes appropriate YAML Front Matter. Here's a basic template:

    ```yaml
    ---
    layout: post
    title: "Your Engaging Post Title"
    excerpt: "A brief summary or teaser for your post that will appear on listing pages."
    date: YYYY-MM-DD HH:MM:SS +ZZZZ # e.g., 2024-07-15 10:00:00 +0800
    categories: [Relevant, Categories] # e.g., [Oracle, GoldenGate]
    tags: [relevant, tags, for, search] # e.g., [oracle, performance, tuning]
    # image: /assets/images/posts/your-image-name.jpg # Optional: path to a relevant image
    ---

    Your post content in Markdown starts here...
    ```

## Contact Us

Interested in learning more about how Goodways IT Team can help your organization, or have questions about our content?
Please [Contact us](https://goodwaysit.github.io/en/contact/).

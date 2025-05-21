---
layout: page
title: Deployment Guide
description: How to deploy the Goodways IT Team blog to GitHub Pages
---

# Goodways IT Team Blog Deployment Guide

This guide explains how to deploy the blog to GitHub Pages and set up your custom domain (it.goodways.co.jp).

## GitHub Repository Setup

1. Create a new GitHub repository named `goodwaysitteam.github.io`
   - The repository must have exactly this name for GitHub Pages to work correctly
   - This name is based on your GitHub organization name (goodwaysitteam)

2. Initialize Git in your local blog directory:

   ```bash
   cd /path/to/blog
   git init
   git add .
   git commit -m "Initial commit"
   ```

3. Connect to your GitHub repository:

   ```bash
   git remote add origin https://github.com/goodwaysitteam/goodwaysitteam.github.io.git
   git push -u origin main
   ```

## GitHub Pages Configuration

1. Go to your GitHub repository at github.com/goodwaysitteam/goodwaysitteam.github.io
2. Navigate to Settings > Pages
3. Under "Source", select "Deploy from a branch"
4. Select branch "gh-pages" and folder "/ (root)"
5. Click "Save"

## Custom Domain Setup

1. In your domain registrar (for it.goodways.co.jp), create the following DNS records:

   | Type  | Host/Name    | Value                    | TTL     |
   |-------|--------------|--------------------------|--------|
   | A     | it           | 185.199.108.153          | 3600   |
   | A     | it           | 185.199.109.153          | 3600   |
   | A     | it           | 185.199.110.153          | 3600   |
   | A     | it           | 185.199.111.153          | 3600   |
   | CNAME | www.it       | goodwaysitteam.github.io | 3600   |

2. In your GitHub repository's Settings > Pages:
   - Enter "it.goodways.co.jp" in the "Custom domain" field
   - Click "Save"
   - Check "Enforce HTTPS" after DNS propagation (may take up to 24 hours)

## Updating the Site

1. Make changes to your local files
2. Test locally with:

   ```bash
   bundle exec jekyll serve
   ```

3. Commit and push changes:

   ```bash
   git add .
   git commit -m "Description of changes"
   git push origin main
   ```

4. GitHub Actions will automatically build and deploy the site
   - You can check build status in the Actions tab of your repository

## Troubleshooting

### Build Failures

If your site fails to build:

1. Check the Actions tab in your GitHub repository for error messages
2. Common issues include:
   - Missing dependencies in Gemfile
   - Syntax errors in Markdown or YAML front matter
   - Invalid Liquid template syntax

### Domain Issues

If your custom domain isn't working:

1. Verify DNS settings with `dig it.goodways.co.jp +nostats +nocomments +nocmd`
2. Check that the CNAME file exists in your repository root
3. Ensure HTTPS is properly configured

## Performance Optimization

1. Optimize images using tools like ImageOptim or TinyPNG
2. Minimize CSS and JavaScript
3. Use Jekyll's incremental build feature for local development: `bundle exec jekyll serve --incremental`

## Security Best Practices

1. Keep Jekyll and all dependencies updated
2. Use HTTPS for all resources
3. Don't commit sensitive information to the repository
4. Regularly review GitHub repository access permissions

## Additional Resources

- [GitHub Pages Documentation](https://docs.github.com/en/pages)
- [Jekyll Documentation](https://jekyllrb.com/docs/)
- [Securing Your GitHub Pages Site with HTTPS](https://docs.github.com/en/pages/getting-started-with-github-pages/securing-your-github-pages-site-with-https)

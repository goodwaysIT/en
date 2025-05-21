---
layout: page
title: Content Guide
description: Guide for adding and managing content on the Goodways IT Team blog
---

# Goodways IT Team Blog Content Guide

This guide explains how to add and manage content on our technical blog. It covers blog posts, service pages, and project case studies, with a focus on multilingual content.

## Adding Blog Posts

### Standard Blog Posts

For regular blog posts in the default language (English), create a new markdown file in the `_posts` directory:

1. Name the file following this format: `YYYY-MM-DD-title-with-hyphens.md`
2. Add the required front matter:

```yaml
---
layout: post
title: "Your Post Title"
excerpt: "A brief description of your post (appears in listings)"
date: YYYY-MM-DD HH:MM:SS +0800
categories: [Category1, Category2]
tags: [tag1, tag2, tag3]
image: /assets/images/posts/image-name.jpg  # Optional featured image
---
```

3. Write your post content in Markdown below the front matter

### Multilingual Blog Posts

For posts in multiple languages, you need to create separate files for each language in their respective directories:

1. English posts go in `_i18n/en/_posts/`
2. Chinese posts go in `_i18n/zh/_posts/`
3. Japanese posts go in `_i18n/ja/_posts/`

The file naming should be identical across all language directories. For example:
- English: `_i18n/en/_posts/2025-05-21-oracle-high-availability.md`
- Chinese: `_i18n/zh/_posts/2025-05-21-oracle-high-availability.md`
- Japanese: `_i18n/ja/_posts/2025-05-21-oracle-high-availability.md`

This ensures that the multilingual plugin connects these as translations of the same post.

## Adding Service Pages

Service pages describe your team's expertise and service offerings:

1. Create a new markdown file in the `_services` directory
2. Add front matter:

```yaml
---
layout: page
title: "Service Title"
description: "Brief description of the service"
excerpt: "Shorter description for service cards"
icon: database  # Font Awesome icon name (without fa-)
order: 1  # Display order (lower numbers appear first)
---
```

3. Write your service description in Markdown below the front matter

### Multilingual Service Pages

For multilingual service pages, create the files in the appropriate language folders:

- English: `_i18n/en/_services/service-name.md`
- Chinese: `_i18n/zh/_services/service-name.md`
- Japanese: `_i18n/ja/_services/service-name.md`

## Adding Project Case Studies

Project case studies showcase your team's successful implementations:

1. Create a new markdown file in the `_projects` directory
2. Add front matter:

```yaml
---
layout: page
title: "Project Title"
description: "Brief description of the project"
excerpt: "Shorter description for project cards"
order: 1  # Display order (lower numbers appear first)
---
```

3. Write your project case study in Markdown below the front matter

## Working with Images

1. Store images in the `assets/images` directory
2. For blog post images, use the `assets/images/posts` subdirectory
3. For service and project images, use `assets/images/services` and `assets/images/projects`
4. Reference images in content using the relative URL: `![Alt text](/assets/images/posts/image-name.jpg)`

## Managing Translations

### UI Translations

**Note: The blog is currently available in English only.**

All UI text elements are hard-coded in English in the respective template files. If you need to modify a UI text element, locate the appropriate template file in `_includes` or `_layouts` directories and directly edit the text.

## Publishing Workflow

1. Write content locally in markdown files
2. Test locally using `bundle exec jekyll serve`
3. Commit changes to Git and push to GitHub repository
4. GitHub Actions will automatically build and deploy the site

## Markdown Tips

### Code Blocks

For code snippets, use triple backticks with the language specified:

```
```sql
SELECT * FROM employees WHERE department_id = 10;
```
```

### Tables

Create tables using pipe syntax:

```
| Header 1 | Header 2 |
|----------|----------|
| Cell 1   | Cell 2   |
| Cell 3   | Cell 4   |
```

### Links

Create links with this syntax: `[Link text](URL)`

For internal links, use relative paths: `[About Us](/about/)`

## SEO Best Practices

1. Use descriptive, keyword-rich titles
2. Write compelling meta descriptions (the `excerpt` field)
3. Use proper heading hierarchy (H1, H2, H3)
4. Include relevant categories and tags
5. Use descriptive alt text for images

## Need Help?

If you have questions about managing content on the blog, contact the Goodways IT Team webmaster.

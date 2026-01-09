---
title: "{{title}}"
source: "{{source_url}}"
created: {{created_date}}
tags: {{tags_yaml_array}}
helix_node_id: "{{helix_node_id}}"
---

# {{title}}

> **Source**: [{{source_title}}]({{source_url}})
> **Curated**: {{created_date}}

## Main Idea

{{main_idea}}

## Key Takeaways

{{#each key_takeaways}}
- {{this}}
{{/each}}

## Notes

{{content}}

with open("lib/screens/room_screen.dart", "r") as f:
    content = f.read()

# 1. Remove the summary table (Member/Items/Amount) section
start_marker = "          const SizedBox(height: 16),\n          // Summary table\n"
end_marker = "          const SizedBox(height: 16),\n          // Items summary"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

print(f"start_idx={start_idx}, end_idx={end_idx}")
if start_idx == -1 or end_idx == -1:
    print("Markers not found!")
    exit(1)

content = content[:start_idx] + content[end_idx:]
print("Removed summary table")

# 2. Add Grand Total row at end of Items Summary table
old_end = "                    }),\n                  ],\n                ),\n              );\n            },\n          ),"

new_end = (
    "                    }),\n"
    "                    // Grand total row\n"
    "                    Container(\n"
    "                      decoration: BoxDecoration(\n"
    "                        color: theme.colorScheme.primaryContainer,\n"
    "                        border: Border(\n"
    "                          top: BorderSide(\n"
    "                            color: theme.colorScheme.outline.withValues(alpha: 0.3),\n"
    "                          ),\n"
    "                        ),\n"
    "                      ),\n"
    "                      padding: const EdgeInsets.symmetric(\n"
    "                        horizontal: 16,\n"
    "                        vertical: 14,\n"
    "                      ),\n"
    "                      child: Row(\n"
    "                        children: [\n"
    "                          const Expanded(\n"
    "                            flex: 8,\n"
    "                            child: Text(\n"
    "                              'Grand Total',\n"
    "                              style: TextStyle(\n"
    "                                fontWeight: FontWeight.bold,\n"
    "                                fontSize: 15,\n"
    "                              ),\n"
    "                            ),\n"
    "                          ),\n"
    "                          Expanded(\n"
    "                            flex: 2,\n"
    "                            child: Text(\n"
    "                              '\u09f3 \${room.grandTotal.toStringAsFixed(2)}',\n"
    "                              textAlign: TextAlign.right,\n"
    "                              style: TextStyle(\n"
    "                                fontWeight: FontWeight.bold,\n"
    "                                fontSize: 16,\n"
    "                                color: theme.colorScheme.onPrimaryContainer,\n"
    "                              ),\n"
    "                            ),\n"
    "                          ),\n"
    "                        ],\n"
    "                      ),\n"
    "                    ),\n"
    "                  ],\n"
    "                ),\n"
    "              );\n"
    "            },\n"
    "          ),"
)

if old_end in content:
    content = content.replace(old_end, new_end, 1)
    print("Added Grand Total row to Items Summary")
else:
    print("Grand total insertion marker not found!")
    idx = content.find("summaryItems.asMap().entries.map")
    print(repr(content[idx + 280 : idx + 480]))
    exit(1)

with open("lib/screens/room_screen.dart", "w") as f:
    f.write(content)
print("Done!")

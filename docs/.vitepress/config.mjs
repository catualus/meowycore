import { defineConfig } from "vitepress"

export default defineConfig({
  title: "Meowy",
  description: "Docs for MeowyCore and the Meowy Garry's Mod addons",
  base: "/meowycore/",
  cleanUrls: true,
  lastUpdated: true,
  appearance: "dark",
  head: [["meta", { name: "theme-color", content: "#ff8a65" }]],
  themeConfig: {
    nav: [
      { text: "Meowy Admin", link: "/admin/" },
      { text: "MeowyCore", link: "/core/" },
      { text: "GitHub", link: "https://github.com/catualus/meowycore" },
    ],
    sidebar: {
      "/admin/": [
        {
          text: "Meowy Admin",
          items: [
            { text: "Getting started", link: "/admin/" },
            { text: "Commands", link: "/admin/commands" },
            { text: "Ranks and permissions", link: "/admin/ranks" },
            { text: "Warnings", link: "/admin/warnings" },
            { text: "Reports and sits", link: "/admin/reports" },
            { text: "Importing from another admin mod", link: "/admin/importing" },
            { text: "Settings", link: "/admin/settings" },
            { text: "For developers", link: "/admin/developers" },
            { text: "FAQ and troubleshooting", link: "/admin/faq" },
          ],
        },
      ],
      "/core/": [
        { text: "MeowyCore", items: [{ text: "Overview", link: "/core/" }] },
      ],
    },
    search: { provider: "local" },
    outline: { level: [2, 3] },
    footer: { message: "MeowyCore is MIT licensed. Meowy Admin is sold on GmodStore." },
  },
})

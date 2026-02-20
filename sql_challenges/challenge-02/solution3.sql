SELECT  pages.page_id FROM pages
LEFT JOIN page_likes ON page_likes.page_id = pages.page_id
WHERE page_likes.page_id IS NULL
ORDER BY page_id;
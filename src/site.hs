--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}

import Data.Functor.Identity (runIdentity)
import Data.Maybe (isJust)
import Data.Text (Text)
import qualified Data.Text as T
import Hakyll
import Text.Pandoc (WriterOptions (writerHighlightStyle, writerNumberSections, writerTOCDepth, writerTableOfContents, writerTemplate))
import Text.Pandoc.Templates (Template, compileTemplate)

--------------------------------------------------------------------------------

main :: IO ()
main = hakyllWith config $ do
  let individualPatterns = fromList ["about.org", "contact.org", "links.org"]

  match "images/**" $ do
    route idRoute
    compile copyFileCompiler

  match "fonts/*" $ do
    route idRoute
    compile copyFileCompiler

  match "css/*" $ do
    route idRoute
    compile compressCssCompiler

  match individualPatterns $ do
    route $ setExtension "html"
    compile $
      pandocCompiler
        >>= loadAndApplyTemplate "templates/default.html" defaultCtx
        >>= relativizeUrls

  tags <- buildTags "posts/*" (fromCapture "archive/tags/*.html")

  tagsRules tags $ \tag pattern -> do
    let title = "Posts tagged \"" ++ tag ++ "\""
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll pattern
      let tagCtx =
            constField "title" title
              <> constField "tag" tag
              <> listField "posts" (postCtx tags) (return posts)
              <> defaultCtx

      makeItem ""
        >>= loadAndApplyTemplate "templates/tag.html" tagCtx
        >>= loadAndApplyTemplate "templates/default.html" tagCtx
        >>= relativizeUrls

  match "posts/*org" $ do
    route $ setExtension "html"
    compile $ do
      identifier <- getUnderlying
      toc <- getMetadataField identifier "enabletoc"
      numbering <- getMetadataField identifier "enablenumbering"
      let writerOptions' = maybe defaultHakyllWriterOptions (const $ writerOptions $ isJust numbering) toc
      pandocCompilerWith defaultHakyllReaderOptions writerOptions'
        >>= saveSnapshot "content"
        >>= loadAndApplyTemplate "templates/post.html" (postCtx tags)
        >>= loadAndApplyTemplate "templates/default.html" (postCtx tags)
        >>= relativizeUrls

  create ["archive.html"] $ do
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll "posts/*"
      let archiveCtx =
            listField "posts" (postCtx tags) (return posts)
              <> constField "title" "Archives"
              <> field "tags" (\_ -> renderTagList tags)
              <> defaultCtx

      makeItem ""
        >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
        >>= loadAndApplyTemplate "templates/default.html" archiveCtx
        >>= relativizeUrls

  match "dailies/*org" $ do
    route $ setExtension "html"
    compile $ do
      pandocCompiler
        >>= saveSnapshot "dailiescontent"
        >>= loadAndApplyTemplate "templates/post.html" dailiesCtx
        >>= loadAndApplyTemplate "templates/default.html" dailiesCtx
        >>= relativizeUrls

  create ["dailies.html"] $ do
    route idRoute
    compile $ do
      dailyToday <- fmap (take 1) . recentFirst =<< loadAllSnapshots "dailies/*" "dailiescontent"
      dailies <- recentFirst =<< loadAll "dailies/*"
      let dailiesCtx' =
            listField "today" dailiesCtx (return dailyToday)
              <> listField "posts" dailiesCtx (return dailies)
              <> constField "title" "Dailies"
              <> defaultCtx

      makeItem ""
        >>= loadAndApplyTemplate "templates/dailies.html" dailiesCtx'
        >>= loadAndApplyTemplate "templates/default.html" dailiesCtx'
        >>= relativizeUrls

  match "index.html" $ do
    route idRoute
    compile $ do
      posts <- fmap (take 10) . recentFirst =<< loadAllSnapshots "posts/*" "content"
      let indexCtx =
            listField "posts" (postCtx tags) (return posts)
              <> defaultCtx

      getResourceBody
        >>= applyAsTemplate indexCtx
        >>= loadAndApplyTemplate "templates/default.html" indexCtx
        >>= relativizeUrls

  create ["rss.xml"] $ do
    route idRoute
    compile $ do
      let feedCtx = postCtx tags <> bodyField "description"
      posts <- fmap (take 10) . recentFirst =<< loadAllSnapshots "posts/*" "content"
      renderRss rssFeedConfiguration feedCtx posts

  -- https://robertwpearce.com/hakyll-pt-2-generating-a-sitemap-xml-file.html
  create ["sitemap.xml"] $ do
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll "posts/*"
      individualPages <- loadAll individualPatterns
      let pages = posts <> individualPages
          sitemapCtx =
            listField "pages" (postCtx tags) (return pages)
              <> defaultCtx
      makeItem ""
        >>= loadAndApplyTemplate "templates/sitemap.xml" sitemapCtx

  match "templates/*" $ compile templateBodyCompiler

rssFeedConfiguration :: FeedConfiguration
rssFeedConfiguration =
  FeedConfiguration
    { feedTitle = "nattopages",
      feedDescription = "Pages by natto",
      feedAuthorName = "Amneesh Singh",
      feedAuthorEmail = "natto@weirdnatto.in",
      feedRoot = "https://weirdnatto.in"
    }

config :: Configuration
config =
  defaultConfiguration
    { deployCommand =
        "rsync --checksum -ave 'ssh -p 22001' \
        \_site/* \
        \root@weirdnatto.in:/var/lib/site/",
      previewPort = 3333
    }

postCtx :: Tags -> Context String
postCtx tags =
  tagsField "tags" tags
    --    <> teaserFieldWithSeparator "((.tease.))" "teaser" "content"
    <> dateField "date" "%B %e, %Y"
    <> dateField "altdate" "%Y-%m-%d"
    <> teaserField "teaser" "content"
    <> defaultCtx

dailiesCtx :: Context String
dailiesCtx =
  dateField "date" "%B %e, %Y"
    <> defaultCtx

defaultCtx :: Context String
defaultCtx =
  listField "subdomains" subCtx (return subdomains)
    <> domainCtx
    <> defaultContext
  where
    domain :: String
    domain = "weirdnatto.in"
    subCtx :: Context String
    subCtx =
      field "name" (return . itemBody)
        <> domainCtx
    domainCtx :: Context String
    domainCtx = constField "domain" domain
    subdomains :: [Item String]
    subdomains = map mkItem ["git", "nomad", "consul", "vault", "radio"]
      where
        mkItem :: a -> Item a
        mkItem a = Item {itemIdentifier = "subdomain", itemBody = a}

writerOptions :: Bool -> WriterOptions
writerOptions withNumbering =
  defaultHakyllWriterOptions
    { writerNumberSections = withNumbering,
      writerTableOfContents = True,
      writerTOCDepth = 2,
      writerTemplate = Just tocTemplate
    }

tocTemplate :: Text.Pandoc.Templates.Template Text
tocTemplate =
  either error id . runIdentity . compileTemplate "" $
    T.unlines
      [ "<div class=\"toc\"><div class=\"toc-header\">Table of Contents</div>",
        "$toc$",
        "</div>",
        "$body$"
      ]

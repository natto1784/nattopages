--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}

import Data.Functor.Identity (runIdentity)
import Data.Text (Text)
import qualified Data.Text as T
import Hakyll
import Text.Pandoc (WriterOptions (writerHighlightStyle, writerNumberSections, writerTOCDepth, writerTableOfContents, writerTemplate))
import Text.Pandoc.Templates (Template, compileTemplate)

--------------------------------------------------------------------------------

main :: IO ()
main = hakyllWith config $ do
  match "images/*" $ do
    route idRoute
    compile copyFileCompiler

  match "css/*" $ do
    route idRoute
    compile compressCssCompiler

  match (fromList ["about.org", "contact.org"]) $ do
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
    compile $
      pandocCompilerWith defaultHakyllReaderOptions writerOptions
        >>= saveSnapshot "content"
        >>= loadAndApplyTemplate "templates/post.html" (postCtx tags <> teaserField "teaser" "content")
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

  match "images/*" $ do
    route idRoute
    compile copyFileCompiler

  match "templates/*" $ compile templateBodyCompiler

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
    <> teaserField "teaser" "content"
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
    subdomains = map mkItem ["git", "nomad", "consul", "vault", "ci", "radio"]
      where
        mkItem :: a -> Item a
        mkItem a = Item {itemIdentifier = "subdomain", itemBody = a}

writerOptions :: WriterOptions
writerOptions =
  defaultHakyllWriterOptions
    { writerNumberSections = True,
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

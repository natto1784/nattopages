--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}

import Data.Monoid (mappend)
import Hakyll

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

  match "posts/*org" $ do
    route $ setExtension "html"
    compile $
      pandocCompiler
        >>= loadAndApplyTemplate "templates/post.html" postCtx
        >>= loadAndApplyTemplate "templates/default.html" postCtx
        >>= relativizeUrls

  create ["archive.html"] $ do
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll "posts/*"
      let archiveCtx =
            listField "posts" postCtx (return posts)
              <> constField "title" "Archives"
              <> defaultCtx

      makeItem ""
        >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
        >>= loadAndApplyTemplate "templates/default.html" archiveCtx
        >>= relativizeUrls

  match "index.html" $ do
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll "posts/*"
      let indexCtx =
            listField "posts" postCtx (return posts)
              <> defaultCtx

      getResourceBody
        >>= applyAsTemplate indexCtx
        >>= loadAndApplyTemplate "templates/default.html" indexCtx
        >>= relativizeUrls

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

postCtx :: Context String
postCtx =
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
    subdomains = map mkItem ["git", "nomad", "consul", "vault", "ci", "radio"]
      where
        mkItem :: a -> Item a
        mkItem a = Item {itemIdentifier = "subdomain", itemBody = a}

import React, { createContext, useContext, useEffect, useMemo } from 'react';
import { useQuery, gql } from '@apollo/client';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import { get } from 'lodash';

// Society branding and locale settings (Settings > Society in the admin).
// Every field is optional: with nothing set the site keeps its built in look.
const SocietyContext = createContext({});

export const useSociety = () => useContext(SocietyContext);

const SOCIETY_QUERY = gql`
  query {
    public_config_config {
      name
      short_name
      logo_url
      primary_color
      public_site_title
      currency
      time_zone
    }
  }
`;

const buildTheme = (primaryColor) => {
  if (primaryColor) {
    try {
      return createTheme({ palette: { primary: { main: primaryColor } } });
    } catch (e) {
      // An unparseable colour must not take the site down; fall back to the default.
      console.warn(`Ignoring invalid primary colour "${primaryColor}"`, e);
    }
  }
  return createTheme();
};

const setFavicon = (href) => {
  const link = document.querySelector("link[rel~='icon']");
  if (!link) {
    return;
  }
  if (!link.dataset.defaultHref) {
    link.dataset.defaultHref = link.getAttribute('href');
  }
  link.setAttribute('href', href || link.dataset.defaultHref);
};

const setDescription = (text) => {
  const meta = document.querySelector("meta[name='description']");
  if (!meta) {
    return;
  }
  if (meta.dataset.defaultContent === undefined) {
    meta.dataset.defaultContent = meta.getAttribute('content') || '';
  }
  meta.setAttribute('content', text || meta.dataset.defaultContent);
};

export const SocietyProvider = ({ children }) => {
  const { data } = useQuery(SOCIETY_QUERY);

  const society = useMemo(() => {
    const config = get(data, 'public_config_config') || {};
    return {
      name: config.name || null,
      shortName: config.short_name || null,
      logoUrl: config.logo_url || null,
      primaryColor: config.primary_color || null,
      publicSiteTitle: config.public_site_title || null,
      currency: config.currency || null,
      timeZone: config.time_zone || null,
      loaded: !!data,
    };
  }, [data]);

  useEffect(() => {
    const title = society.publicSiteTitle || society.name;
    if (title) {
      document.title = title;
    }
    setDescription(society.name);
  }, [society.publicSiteTitle, society.name]);

  useEffect(() => {
    setFavicon(society.logoUrl);
  }, [society.logoUrl]);

  const theme = useMemo(() => buildTheme(society.primaryColor), [society.primaryColor]);

  return (
    <SocietyContext.Provider value={society}>
      <ThemeProvider theme={theme}>
        {children}
      </ThemeProvider>
    </SocietyContext.Provider>
  );
};

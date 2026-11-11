import React, { createContext, useContext, useEffect, useMemo } from 'react';
import { useQuery, gql } from '@apollo/client';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import { get } from 'lodash';

// Society branding and locale settings (Settings > Society). Every field is
// optional: with nothing set the admin keeps its built in look.
const SocietyContext = createContext({});

export const useSociety = () => useContext(SocietyContext);

// The admin header colour used when no primary colour is set.
export const DEFAULT_HEADER_COLOR = '#1D7C81';

const SOCIETY_QUERY = gql`
  query {
    config_config {
      name
      short_name
      logo_url
      primary_color
      currency
      time_zone
    }
  }
`;

// Returns a theme only for a colour MUI can parse, so an unparseable colour
// leaves the admin exactly as it looks with no colour set.
const buildTheme = (primaryColor) => {
  if (primaryColor) {
    try {
      return createTheme({ palette: { primary: { main: primaryColor } } });
    } catch (e) {
      console.warn(`Ignoring invalid primary colour "${primaryColor}"`, e);
    }
  }
  return null;
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

// Formats an ISO 8601 instant as a date and time in the society's time zone,
// e.g. "Wed 11 Nov 2026, 09:30 GMT". Falls back to the browser's zone when
// the society has none or the zone is unknown to the browser.
export const formatInTimeZone = (iso, timeZone) => {
  if (!iso) {
    return null;
  }
  const date = new Date(iso);
  if (isNaN(date.getTime())) {
    return iso;
  }
  const options = {
    weekday: 'short', day: 'numeric', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit', timeZoneName: 'short',
  };
  try {
    return new Intl.DateTimeFormat('en-GB', { ...options, timeZone: timeZone || undefined }).format(date);
  } catch (e) {
    return new Intl.DateTimeFormat('en-GB', options).format(date);
  }
};

export const SocietyProvider = ({ children }) => {
  const { data } = useQuery(SOCIETY_QUERY);

  const config = useMemo(() => get(data, 'config_config') || {}, [data]);
  const brandTheme = useMemo(() => buildTheme(config.primary_color), [config.primary_color]);
  const theme = useMemo(() => brandTheme || createTheme(), [brandTheme]);

  const society = useMemo(() => {
    return {
      name: config.name || null,
      shortName: config.short_name || null,
      logoUrl: config.logo_url || null,
      // Only set when the colour is valid and the theme is using it.
      primaryColor: brandTheme ? config.primary_color : null,
      currency: config.currency || null,
      timeZone: config.time_zone || null,
      loaded: !!data,
    };
  }, [config, brandTheme, data]);

  useEffect(() => {
    const name = society.shortName || society.name;
    if (name) {
      document.title = `${name} admin`;
    }
  }, [society.shortName, society.name]);

  useEffect(() => {
    setFavicon(society.logoUrl);
  }, [society.logoUrl]);

  return (
    <SocietyContext.Provider value={society}>
      <ThemeProvider theme={theme}>
        {children}
      </ThemeProvider>
    </SocietyContext.Provider>
  );
};

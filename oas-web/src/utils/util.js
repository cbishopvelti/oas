import { get, snakeCase } from 'lodash';
import { useState } from "react"
import {
  TableRow,
} from '@mui/material'
import { styled } from '@mui/material/styles';

export const parseErrors = (errors) => {
  if (!errors) {
    return {}
  }
  return errors.reduce((acc, error) => {
    if (error.db_field) {
      return {
        ...acc, 
        [error.db_field]: [error.message, ...get(acc, error.db_field, [])],
      }
    }

    let result;
    const regex = /(In\s(argument|field)|Variable|Argument)\s"(.+?)"(:|\shas)\s([^\.]+.)/g;
    let found = false;
    while(result = regex.exec(error.message)) {
      const key = snakeCase(result[3]);
      acc = {
        ...acc,
        [key]: [result[5], ...get(acc, key, [])]
      }
      found = true
    }
    if ( found == false) {
      acc = {
        ...acc,
        global: [error.message, ...get(acc, "global", [])]
      }
    }
    
    return acc;
  }, {})
}

export const StyledTableRow = styled(TableRow)(({ theme }) => {
  return {
    '&.errors, &.warnings.errors': {
      backgroundColor: theme.palette.error.main
    },
    '&.warnings': {
      backgroundColor: theme.palette.warning.main
    },
    '&.warnings > *, &.errors > *': {
      borderBottom: 'unset'
    }
  }
});
import { useQuery, gql, useMutation } from "@apollo/client"
import { useEffect } from "react"
import {
  Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  IconButton,
  Box,
  FormControl,
  TextField,
  Button
} from '@mui/material';
import { get } from 'lodash';
import FitnessCenterIcon from '@mui/icons-material/FitnessCenter';
import DeleteIcon from '@mui/icons-material/Delete';
import { Link, useOutletContext } from "react-router-dom";
import { StyledTableRow } from '../utils/util';
import moment from 'moment';
import { useState } from '../utils/useState';

export const Things = () => {
  const { setTitle } = useOutletContext();

  const {data, refetch} = useQuery(gql`
    query {
      things {
        id,
        what,
        when,
        value
      },
    }
  `, {
    variables: {
    }
  })
  useEffect(() => {
    refetch()
  }, [])
  useEffect(() => {
    let count = (get(data, ['things'], []) || []).length
    setTitle(`Things: ${count}`);
  }, [data])

  const things = get(data, 'things', [])

  const [deleteMutation, {error}] = useMutation(gql`
    mutation($id: Int!) {
      delete_training_where(id: $id) {
        success
      }
    }
  `,
  {
    onError: (error, {variables}, c) => {
      // return {id: variables.id, message: error.message}
    }
  })

  const deleteThingClick = (id) => async () => {
    await deleteMutation({
      variables: {
        id: id
      }
    })
    refetch();
  }

  return <TableContainer>
    <Table>
      <TableHead>
        <TableRow>
          <TableCell>Id</TableCell>
          <TableCell>What</TableCell>
          <TableCell>Value</TableCell>
          <TableCell>When</TableCell>
          <TableCell>Actions</TableCell>
        </TableRow>
      </TableHead>
      <TableBody>
        {
            (things || []).map((thing) => {
              const thisError = (error?.graphQLErrors || []).find(({id}) => id === thing.id)?.message
              return (
                [
                  <TableRow key={`row-${thing.id}`}>
                    <TableCell>{thing.id}</TableCell>
                    <TableCell>{thing.what}</TableCell>
                    <TableCell>{thing.value}</TableCell>
                    <TableCell>{thing.when}</TableCell>
                    <TableCell>
                      <IconButton title={`Edit ${thing.name}`} component={Link} to={`/thing/${thing.id}`}>
                        <FitnessCenterIcon />
                      </IconButton>
                      {<IconButton title={`Delete ${thing.id}`} onClick={deleteThingClick(thing.id)}>
                        <DeleteIcon sx={{ color: 'red' }} />
                      </IconButton>}
                    </TableCell>
                  </TableRow>,
                  ...(thisError ? [<StyledTableRow className="errors" key={`row-error-${thing.id}`}>
                    <TableCell colSpan={4}>
                       Delete failed: {thisError}
                    </TableCell>
                  </StyledTableRow>] : [])
                ]
              )
            })
        }
      </TableBody>
    </Table>
  </TableContainer>
}

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

export const Venues = () => {
  const { setTitle } = useOutletContext();

  const {data, refetch} = useQuery(gql`
    query {
      training_wheres {
        id,
        name,
        credit_amount
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
    let count = (get(data, ['training_wheres'], []) || []).length
    setTitle(`Venues: ${count}`);
  }, [data])

  const training_wheres = get(data, 'training_wheres', [])

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

  const deleteTraningClick = (id) => async () => {
    await deleteMutation({
      variables: {
        id: id
      }
    })
    refetch();
  }

  return <>
    <TableContainer>
    <Table>
      <TableHead>
        <TableRow>
          <TableCell>Id</TableCell>
          <TableCell>Name</TableCell>
          <TableCell>Amount</TableCell>
          <TableCell>Actions</TableCell>
        </TableRow>
      </TableHead>
      <TableBody>
        {
            (training_wheres || []).map((training_where) => {
              const thisError = (error?.graphQLErrors || []).find(({id}) => id === training_where.id)?.message
              return (
                <>
                  <TableRow key={`row-${training_where.id}`}>
                    <TableCell>{training_where.id}</TableCell>
                    <TableCell>{training_where.name}</TableCell>
                    <TableCell>{training_where.credit_amount}</TableCell>
                    <TableCell>
                      <IconButton title={`Edit ${training_where.name}`} component={Link} to={`/venue/${training_where.id}`}>
                        <FitnessCenterIcon />
                      </IconButton>
                      {<IconButton title={`Delete ${training_where.id}`} onClick={deleteTraningClick(training_where.id)}>
                        <DeleteIcon sx={{ color: 'red' }} />
                      </IconButton>}
                    </TableCell>
                  </TableRow>
                  {thisError && <StyledTableRow className="errors" key={`row-error-${training_where.id}`}>
                    <TableCell colSpan={4}>
                      Delete failed: {thisError}
                    </TableCell>
                  </StyledTableRow>}
                </>
              )
            })
        }
      </TableBody>
    </Table>
  </TableContainer>
  </>
}

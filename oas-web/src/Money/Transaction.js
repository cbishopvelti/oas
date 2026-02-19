import { useEffect, useState, Fragment } from 'react'
import {
  Box,
  FormControl,
  TextField,
  Autocomplete,
  Select,
  MenuItem,
  InputLabel,
  Button,
  Stack,
  Alert
} from '@mui/material'
import { createFilterOptions } from '@mui/material/Autocomplete';
import { get, find, omit, has } from 'lodash'
import * as moment from 'moment'
import { useParams, useNavigate, useOutletContext, Link } from 'react-router-dom'
import { useQuery, gql, useMutation } from '@apollo/client';
import { TransactionNewToken, TransactionEditTokens } from "./TransactionToken";
import { Tokens } from './Tokens';
import { TransactionTags } from './TransactionTags';
import { TransactionMembershipPeriod } from './TransactionMembershipPeriod';
import { parseErrors } from '../utils/util';
import { IconButton } from '@mui/material';
import LinkIcon from '@mui/icons-material/Link';
import { TransactionCredits } from './TransactionCredits';
import SyncIcon from '@mui/icons-material/Sync';


export const Transaction = () => {
  const { setTitle } = useOutletContext();

  const navigate = useNavigate();
  let { id } = useParams()
  if (id) {
    id = parseInt(id);
  }

  const defaultData = {
    when: moment().format("YYYY-MM-DD")
  };

  let [formData, setFormData] = useState(defaultData);

  const {data, refetch} = useQuery(gql`
    query ($id: Int!) {
      transaction (id: $id) {
        id,
        what,
        when,
        who,
        who_member_id,
        type,
        amount,
        bank_details,
        notes,
        their_reference,
        my_reference,
        warnings,
        transaction_tags {
          id,
          name
        },
        tokens {
          id
        },
        membership {
          membership_period_id
        },
        credit {
          amount,
          expires_on
        }
      }
    }
  `, {
    variables: {
      id
    },
    skip: !id
  })
  useEffect(() => {
    if (!id) {
      setTitle("New Transaction");
    } else {
      setTitle(`Editing Transaction: ${id}`)
      refetch()
    }
    if (!id) {
      setFormData(() => defaultData)
    }
  }, [id])
  useEffect(() => {
    if (get(data, "transaction")) {
      setFormData((prevFormData) => ({
        ...{
          auto_tags: get(prevFormData, "auto_tags", [])
        },
        ...get(data, "transaction", {}),
        ...(has(data, "transaction.membership.membership_period_id") ? { membership_period_id: get(data, "transaction.membership.membership_period_id")} : {})
      }));
    }
  }, [data])
  useEffect(() => {
    if (formData.type === "INCOMING") {
      setFormData((prevFormData) => ({
        ...omit(prevFormData, 'their_reference'),
      }))
    }
  }, [formData.type])


  let { data: membersData, refetch: refetechMembers } = useQuery(gql`query {
    members {
      id,
      name
    }
  }`);
  const members = get(membersData, 'members', [])
  useEffect(() => {
    refetechMembers()
  }, [])

  const onChange = ({formData, setFormData, key}) => (event) => {
    let extraData = {}
    if(key == 'amount' && !formData.type) {
      if (parseFloat(event.target.value) >= 0) {
        extraData = {
          ...extraData,
          type: 'INCOMING'
        }
      } else if (parseFloat(event.target.value) < 0) {
        extraData = {
          ...extraData,
          type: 'INCOMING'
        }
      }
    }

    setFormData({
      ...formData,
      ...extraData,
      [key]: !event.target.value ? undefined : event.target.value
    })
  }

  const filter = createFilterOptions();

  const { data: dupData, refetch: dupRefetch } = useQuery(gql`
    query($when: String!, $amount: Float!, $who: String!) {
      check_duplicate(when: $when, amount: $amount, who: $who)
    }
  `, {
    variables: {
      when: formData.when,
      who: formData.who,
      amount: parseFloat(get(formData, 'amount'))
    },
    skip: !formData.amount || !formData.who || !formData.when || id
  })
  useEffect(() => {
    if (!formData.amount || !formData.who || !formData.when || id) {
      return;
    }
    dupRefetch()
  }, [formData])

  const [whoLinkMutate, { data: whoData}] = useMutation(gql`mutation(
    $who_member_id: Int!,
    $gocardless_name: String!
    ) {
      gocardless_who_link (
        who_member_id: $who_member_id,
        gocardless_name: $gocardless_name
      ) {
        success
      }
    }
  `)

  const [reprocessTranactionMutate, {data: reprocessTransactionData}] = useMutation(gql`
    mutation(
      $who_member_id: Int!,
      $id: Int!
    ) {
      reprocess_transaction(id: $id, who_member_id: $who_member_id) {
        success
      }
    }
  `)

  const [clearWarnings, {data: clearWarningsData}] = useMutation(gql`mutation(
    $transaction_id: Int!
    ) {
      transaction_clear_warnings(transaction_id: $transaction_id) {
        success
      }
    }
  `)

  const [mutate, {error}] = useMutation(gql`mutation (
    $id: Int,
    $what: String!,
    $when: String!,
    $who: String,
    $who_member_id: Int,
    $type: String!,
    $amount: Float!,
    $bank_details: String,
    $notes: String,
    $token_quantity: Int,
    $token_value: Float,
    $transaction_tags: [TransactionTagArg],
    $membership_period_id: Int,
    $their_reference: String,
    $my_reference: String!,
    $credit: CreditArg,
    $auto_tags: [TransactionTagArg]
  ){
    transaction (
      id: $id,
      what: $what,
      when: $when,
      who: $who,
      who_member_id: $who_member_id,
      type: $type,
      amount: $amount,
      bank_details: $bank_details,
      notes: $notes,
      token_quantity: $token_quantity,
      token_value: $token_value,
      transaction_tags: $transaction_tags,
      membership_period_id: $membership_period_id,
      their_reference: $their_reference,
      my_reference: $my_reference,
      credit: $credit,
      auto_tags: $auto_tags
    ) {
      id
    }
  }`)
  const errors = parseErrors(error?.graphQLErrors);
  const save = (formData) => async () => {
    formData = omit(formData, "training_tags.__typename");

    const variables = {
      ...formData,
      amount: parseFloat(get(formData, 'amount')),
      ...(get(formData, 'who_member_id') ? {who_member_id: parseInt(get(formData, 'who_member_id'))} : {}),
      ...(formData.token_quantity ? {token_quantity: parseInt(formData.token_quantity)}: {}),
      ...(formData.token_quantity ? {token_value: parseFloat(formData.token_value)}: {}),
      transaction_tags: (formData.transaction_tags?.map((item) => omit(item, '__typename'))),
      auto_tags: (formData.auto_tags?.map((item) => omit(item, '__typename'))),
      ...(formData.tokens ? {tokens: formData.tokens.map((item) => omit(item, '__typename'))} : {}),
      ...(formData.credit?.amount ? { credit: { amount: parseFloat( formData.credit?.amount) } } : {})
    };

    const { data } = await mutate({
      variables
    });

    setFormData({
      ...formData,
      saveCount: get(formData, "saveCount", 0) + 1
    })

    // return; // DEBUG ONLY, remove

    refetch()
    navigate(`/transaction/${get(data, 'transaction.id')}`)
  }

  return <>
    <Box sx={{display: 'flex', flexWrap: 'wrap' }}>
      <Stack sx={{ width: '100%' }}>
        {errors.global?.map((message, i) => (
          <Alert key={i} sx={{m:2}} severity="error">{message}</Alert>
        ))}
        {
          JSON.parse(data?.transaction?.warnings || "[]").length > 0 &&
          clearWarningsData?.transaction_clear_warnings?.success !== true &&
          <Alert sx={{m:2}} severity="warning"
            onClose={() => {clearWarnings({variables: {
              transaction_id: id
            }})}}
          >
            {(JSON.parse(data?.transaction?.warnings || "[]")).map((message, i) => (
              <div key={i}>{message}</div>
            ))}
          </Alert>
        }
      </Stack>
      <FormControl fullWidth sx={{m: 2}}>
        <TextField
          required
          id="what"
          label="What"
          value={get(formData, "what", '')}
          onChange={onChange({formData, setFormData, key: "what"})}
          error={has(errors, "what")}
          helperText={get(errors, "what", []).join(' ')}
        />
      </FormControl>
      <FormControl fullWidth sx={{m: 2}}>
        <TextField
          required
          id="when"
          label="When"
          value={get(formData, "when", '')}
          type="date"
          onChange={
            onChange({formData, setFormData, key: "when"})
          }
          InputLabelProps={{
            shrink: true,
          }}
          error={has(errors, "when")}
          helperText={get(errors, "when", []).join(' ')}
          />
      </FormControl>

      <FormControl fullWidth sx={{m: 2}}>
        <Autocomplete
            id="member"
            freeSolo
            required
            value={formData.who || find(members, ({id}) => id === formData.who_member_id)?.name || ''}
            options={(members || []).map(({name, id}) => ({label: name, who_member_id: id }))}
            renderInput={(params) => <TextField
              {...params}
              InputProps={{
                ...params.InputProps,
                endAdornment: (<Fragment>
                  {params.InputProps.endAdornment}
                  {data?.transaction?.who_member_id == null &&
                    data?.transaction.who &&
                    formData.who !== data?.transaction?.who &&
                    formData.who_member_id != null &&
                    whoData?.gocardless_who_link?.success !== true &&
                    <IconButton title="Link this gocardless id to this member (wont save/effect this transaction, as save will also be required)" sx={{ color: "#0000EE;" }} onClick={() => {
                      whoLinkMutate({
                        variables: {
                          gocardless_name: data.transaction.who,
                          who_member_id: formData.who_member_id
                        }
                      })
                    }}>
                      <LinkIcon />
                    </IconButton>}
                  {
                    data?.transaction?.id &&
                    formData.who_member_id &&
                    data?.transaction?.who_member_id !== formData.who_member_id &&
                    data?.transaction?.tokens?.length === 0 &&
                    !data?.transaction?.credit &&
                    !data?.transaction?.membership &&
                    <IconButton
                    title="Reprocess this transaction now that who has been set."
                    sx={{ color: "#0000EE;" }}
                    onClick={async () => {
                      await reprocessTranactionMutate({
                        variables: {
                          id: data?.transaction?.id,
                          who_member_id: formData.who_member_id
                        }
                      })
                      refetch();
                    }}>
                    <SyncIcon />
                  </IconButton>}
                </Fragment>
                )
              }}
              label="Who"
              required
              error={has(errors, "who") || has(errors, "who_member_id")}
              helperText={[...get(errors, "who", []), get(errors, "who_member_id", [])].join(' ')}
              />
            }
            filterOptions={(options, params) => {

              const filtered = filter(options, params);

              const { inputValue } = params;

              let add = []
              const isExisting = options.some((option) => inputValue === option.label);
              if (inputValue && !isExisting) {
                add = [{label: `Pay "${inputValue}"`, who: inputValue}]
              }

              return [...add, ...filtered];
            }}
            clearOnBlur
            selectOnFocus
            handleHomeEndKeys
            onChange={(event, newValue, a, b, c, d) => {
              if (newValue?.who) {
                setFormData({
                  ...formData,
                  who: newValue.who,
                  who_member_id: null
                })
              } else if (newValue?.who_member_id) {
                setFormData({
                  ...formData,
                  who: newValue.label,
                  who_member_id: newValue.who_member_id
                })
              } else {
                setFormData({
                  ...formData,
                  who: null,
                  who_member_id: null
                })
              }
            }}
          />
      </FormControl>

      <FormControl fullWidth sx={{m: 2}}>
        <InputLabel required id="transaction-type">Type</InputLabel>

        <Select
          labelId="transaction-type"
          label="Type"
          required
          onChange={onChange({formData, setFormData, key: "type"})}
          value={get(formData, "type", '')}
          error={has(errors, "type")}
        >
          <MenuItem value={'INCOMING'}>Incoming</MenuItem>
          <MenuItem value={'OUTGOING'}>Outgoing</MenuItem>
        </Select>
      </FormControl>

      <FormControl fullWidth sx={{m:2, display: 'flex', flexWrap: 'wrap', justifyContent: 'space-between', gap: 2, flexDirection: 'row'}}>
        {(get(formData, 'type') == 'OUTGOING') && <TextField
          sx={{flexGrow: 1}}
          label="Their Reference"
          value={get(formData, "their_reference", '') || ''}
          onChange={onChange({formData, setFormData, key: 'their_reference'})}
          error={has(errors, "their_reference")}
          helperText={get(errors, "their_reference", []).join(' ')}
          />}

        <TextField
          sx={{flexGrow: 1}}
          label={`${((get(formData, 'type') === 'OUTGOING') ? 'My' : 'Received')} Reference`}
          value={get(formData, "my_reference", '') || ''}
          required
          onChange={onChange({formData, setFormData, key: "my_reference"})}
          error={has(errors, "my_reference")}
          helperText={get(errors, "my_reference", []).join(' ')}
          />
      </FormControl>

      <FormControl fullWidth sx={{m: 2}}>
        <TextField
          label="Amount"
          value={get(formData, "amount", '')}
          type="text"
          inputMode="numeric"
          pattern="[0-9\.]*"
          required
          onChange={onChange({formData, setFormData, key: "amount"})}
          error={has(errors, "amount")}
          helperText={get(errors, "amount", []).join(' ')}
        />
      </FormControl>

      <FormControl fullWidth sx={{m: 2}}>
        <TransactionTags
          who={get(formData, "who", '')}
          who_member_id={get(formData, "who_member_id", null)}
          formData={formData}
          setFormData={setFormData}
        />
      </FormControl>

      <FormControl fullWidth sx={{m:2}}>
        <TextField
          label="Bank Details"
          value={get(formData, "bank_details", '') || ''}
          multiline
          onChange={onChange({formData, setFormData, key: "bank_details"})}
          error={has(errors, "bank_details")}
          helperText={get(errors, "bank_details", []).join(' ')}
          />

      </FormControl>

      <FormControl fullWidth sx={{m:2}}>
        <TextField
          label="Notes"
          value={get(formData, "notes", '') || ''}
          multiline
          onChange={onChange({formData, setFormData, key: "notes"})}
          error={has(errors, "notes")}
          helperText={get(errors, "notes", []).join(' ')}
          />
      </FormControl>

      <TransactionCredits
        formData={formData}
        data={get(data, "transaction.credit")}
        setFormData={setFormData}
        id={id}
        errors={errors}
      />

      <TransactionMembershipPeriod
        formData={formData}
        setFormData={setFormData}
        id={id}
      />

      <TransactionNewToken
        formData={formData}
        setFormData={setFormData}
        id={id} />

      {get(dupData, 'check_duplicate', null) != null && <Stack sx={{width: '100%'}}>
        <Alert sx={{m: 2}} severity="warning">This is a duplicate of <Link to={`/transaction/${get(dupData, 'check_duplicate')}`}>/transaction/{get(dupData, 'check_duplicate')}</Link></Alert>
      </Stack>}

      <FormControl fullWidth sx={{m: 2}}>
        <Button onClick={save(formData)}>Save</Button>
      </FormControl>

    </Box>
    {get(data, "transaction") && <TransactionEditTokens
      formData={formData}
      refetch={refetch}
      transaction={get(data, "transaction")} />}
    {/* {get(data, "transaction") && <Tokens transaction={get(data, "transaction")} />} */}
  </>
}

"""
Fill an array, context, with every _atomic_ value our features reference.
We then write the _actual features_ as tuples of the atoms. The machinery
that translates from the tuples to feature-extractors (which pick the values
out of "context") is in features/extractor.pyx

The atomic feature names are listed in a big enum, so that the feature tuples
can refer to them.
"""

from redshift._state cimport Kernel, Subtree
from itertools import combinations
# Context elements
# Ensure _context_size is always last; it ensures our compile-time setting
# is in synch with the enum
# Ensure each token's attributes are listed: w, p, c, c6, c4. The order
# is referenced by incrementing the enum...
# Tokens are listed in left-to-right order.
#cdef size_t* SLOTS = [
#    S2w, S1w,
#    S0l0w, S0l2w, S0lw,
#    S0w,
#    S0r0w, S0r2w, S0rw,
#    N0l0w, N0l2w, N0lw,
#    N0w, N1w, N2w, N3w, 0
#]
# NB: The order of the enum is _not arbitrary!!_
cdef enum:
    S2w
    S2p
    S2c
    S2c6
    S2c4

    S1w
    S1p
    S1c
    S1c6
    S1c4

    S0l0w
    S0l0p
    S0l0c
    S0l0c6
    S0l0c4

    S0l2w
    S0l2p
    S0l2c
    S0l2c6
    S0l2c4

    S0lw
    S0lp
    S0lc
    S0lc6
    S0lc4

    S0w
    S0p
    S0c
    S0c6
    S0c4

    S0r0w
    S0r0p
    S0r0c
    S0r0c6
    S0r0c4

    S0r2w
    S0r2p
    S0r2c
    S0r2c6
    S0r2c4

    S0rw
    S0rp
    S0rc
    S0rc6
    S0rc4

    N0l0w
    N0l0p
    N0l0c
    N0l0c6
    N0l0c4

    N0l2w
    N0l2p
    N0l2c
    N0l2c6
    N0l2c4

    N0lw
    N0lp
    N0lc
    N0lc6
    N0lc4

    N0w
    N0p
    N0c
    N0c6
    N0c4
 
    N1w
    N1p
    N1c
    N1c6
    N1c4
    
    N2w
    N2p
    N2c
    N2c6
    N2c4
    
    N3w
    N3p
    N3c
    N3c6
    N3c4

    S0hw
    S0hp
    S0hc
    S0hc6
    S0hc4
 
    S0h2w
    S0h2p
    S0h2c
    S0h2c6
    S0h2c4
    
    S0le_w
    S0le_p
    S0le_c
    S0le_c6
    S0le_c4
    
    S0re_w
    S0re_p
    S0re_c
    S0re_c6
    S0re_c4
    
    N0le_w
    N0le_p
    N0le_c
    N0le_c6
    N0le_c4

    S2l
    S1l
    
    S0l0l
    S0l2l
    S0ll

    S0l

    S0r0l
    S0r2l
    S0rl
    
    N0l0l
    N0l2l
    N0ll

    S0hl
    S0h2l
    
    S0le_l
    S0re_l
    N0le_l
    
    S0lv
    S0rv
    N0lv
    
    dist
    
    S0llabs
    S0rlabs
    N0llabs
    
    prev_edit
    prev_edit_wmatch
    prev_edit_pmatch
    prev_edit_word
    prev_edit_pos
    prev_prev_edit

    next_edit
    next_edit_wmatch
    next_edit_pmatch
    next_edit_word
    next_edit_pos
    next_next_edit

    wcopy 
    pcopy

    wexact
    pexact

    wscopy
    pscopy

    wsexact
    psexact

    CONTEXT_SIZE


# Listed in left-to-right order
cdef size_t* SLOTS = [
    S2w, S1w,
    S0le_w, S0l0w, S0l2w, S0lw,
    S0w,
    S0r0w, S0r2w, S0rw, S0re_w,
    N0le_w, N0l0w, N0l2w, N0lw,
    N0w
]

cdef size_t NR_SLOT = sizeof(SLOTS) / sizeof(SLOTS[0])

def context_size():
    return CONTEXT_SIZE

cdef inline void fill_token(size_t* context, size_t slot, Token* token,
                            size_t tag, size_t label,
                            size_t left_valency, size_t right_valency):
    context[slot] = token.word
    # TODO: Implement 4 and 6 bit cluster prefixes
    context[slot+1] = token.cluster
    context[slot+2] = token.cluster
    context[slot+3] = token.cluster
    context[slot+4] = tag
    context[slot+5] = label
    context[slot+6] = left_valency
    context[slot+7] = right_valency


cdef void fill_context(size_t* context, size_t nr_label, Token** tokens, Kernel* k):
    # This fills in the basic properties of each of our "slot" tokens, e.g.
    # word on top of the stack, word at the front of the buffer, etc.
    cdef size_t i
    cdef size_t slot
    cdef Token* token
    for i in range(NR_SLOT):
        fill_token(context, SLOTS[i], tokens[i], k.tags[i], k.labels[i],
                   k.l_vals[i], k.r_vals[i])

    fill_token(context, N1w, tokens[k.i + 1], 0, 0, 0, 0)
    fill_token(context, N2w, tokens[k.i + 2], 0, 0, 0, 0)
    fill_token(context, N3w, tokens[k.i + 3], 0, 0, 0, 0)
        
    fill_token(context, S0hw, tokens[k.s1 if k.Ls0 else 0], k.s1p)
    fill_token(context, S0hw, tokens[k.s2 if k.Ls0 and k.Ls1 else 0], k.s2p)
    # Edge features for disfluencies 
    fill_token(context, S0le_w, tokens[k.s0ledge], k.s0ledgep)
    fill_token(context, N0le_w, tokens[k.n0ledge], k.s0ledgep)
    # Get rightward edge of S0 via the leftward edge of N0
    fill_token(context, S0re_w, tokens[k.n0ledge-1 if k.n0ledge else 0], k.s0redgep)
    

    # Label features for stack
    context[S0l] = k.Ls0
    context[S0hl] = k.Ls1
    context[S0h2l] = k.Ls2
    
    # Valency features
    context[S0lv] = k.s0l.val + 1
    context[S0rv] = k.s0r.val + 1
    context[N0lv] = k.n0l.val + 1

    # Label features for subtrees
    context[S0ll] = k.s0l.lab[0]
    context[S0l2l] = k.s0l.lab[1]
    context[S0l0l] = k.s0l.lab[2]
    context[S0rl] = k.s0r.lab[0]
    context[S0r2l] = k.s0r.lab[1]
    context[S0r0l] = k.s0r.lab[2]
    context[N0ll] = k.n0l.lab[0]
    context[N0l2l] = k.n0l.lab[1]
    context[N0l0l] = k.n0l.lab[2]

    # Label "set" features. Are these necessary??
    context[S0llabs] = 0
    context[S0rlabs] = 0
    context[N0llabs] = 0
    cdef size_t i
    for i in range(4):
        context[S0llabs] += k.s0l.lab[i] << (nr_label - k.s0l.lab[i])
        context[S0rlabs] += k.s0r.lab[i] << (nr_label - k.s0r.lab[i])
        context[N0llabs] += k.n0l.lab[i] << (nr_label - k.n0l.lab[i])
    # TODO: Seems hard to believe we want to keep d non-zero when there's no
    # stack top. Experiment with this futrther.
    if k.s0 != 0:
        assert k.i > k.s0
        context[dist] = k.i - k.s0
    else:
        context[dist] = 0

    # Disfluency match features
    if k.prev_edit and k.i != 0:
        context[prev_edit] = 1
        context[prev_edit_wmatch] = 1 if words[k.i - 1] == words[k.i] else 0
        context[prev_edit_pmatch] = 1 if k.prev_tag == tags[k.i] else 0
        context[prev_prev_edit] = 1 if k.prev_prev_edit else 0
        context[prev_edit_word] = words[k.i - 1]
        context[prev_edit_pos] = k.prev_tag
    else:
        context[prev_edit] = 0
        context[prev_edit_wmatch] = 0
        context[prev_edit_pmatch] = 0
        context[prev_prev_edit] = 0
        context[prev_edit_word] = 0
        context[prev_edit_pos] = 0
    if k.next_edit and k.s0 != 0:
        context[next_edit] = 1
        context[next_edit_wmatch] = 1 if words[k.s0 + 1] == words[k.s0] else 0
        context[next_edit_pmatch] = 1 if tags[k.s0 + 1] == tags[k.s0] else 0
        context[next_next_edit] = 1 if k.next_next_edit else 0
        context[next_edit_word] = words[k.s0 + 1]
        context[next_edit_pos] = k.next_tag
    else:
        context[next_edit] = 0
        context[next_edit_wmatch] = 0
        context[next_edit_pmatch] = 0
        context[next_next_edit] = 0
        context[next_edit_word] = 0
        context[next_edit_pos] = 0

    # These features find how much of S0's span matches N0's span, starting from
    # the left.
    # 
    context[wcopy] = 0
    context[wexact] = 1
    context[pcopy] = 0
    context[pexact] = 1
    context[wscopy] = 0
    context[wsexact] = 1
    context[pscopy] = 0
    context[psexact] = 1
    for i in range(5):
        if ((k.n0ledge + i) > k.i) or ((k.s0ledge + i) > k.s0):
            break
        if context[wexact]:
            if words[k.n0ledge + i] == words[k.s0ledge + i]:
                context[wcopy] += 1
            else:
                context[wexact] = 0
        if context[pexact]:
            if tags[k.n0ledge + i] == tags[k.s0ledge + i]:
                context[pcopy] += 1
            else:
                context[pexact] = 0
        if context[wsexact]:
            if words[k.s0 - i] == words[k.i - i]:
                context[wscopy] += 1
            else:
                context[wsexact] = 0
        if context[psexact]:
            if tags[k.s0 - i] == tags[k.i - i]:
                context[pscopy] += 1
            else:
                context[psexact] = 0


from_single = (
    (S0w, S0p),
    (S0w,),
    (S0p,),
    (N0w, N0p),
    (N0w,),
    (N0p,),
    (N1w, N1p),
    (N1w,),
    (N1p,),
    (N2w, N2p),
    (N2w,),
    (N2p,)
)


from_word_pairs = (
   (S0w, S0p, N0w, N0p),
   (S0w, S0p, N0w),
   (S0w, N0w, N0p),
   (S0w, S0p, N0p),
   (S0p, N0w, N0p),
   (S0w, N0w),
   (S0p, N0p),
   (N0p, N1p)
)


from_three_words = (
   (N0p, N1p, N2p),
   (S0p, N0p, N1p),
   (S0hp, S0p, N0p),
   (S0p, S0lp, N0p),
   (S0p, S0rp, N0p),
   (S0p, N0p, N0lp)
)


distance = (
   (dist, S0w),
   (dist, S0p),
   (dist, N0w),
   (dist, N0p),
   (dist, S0w, N0w),
   (dist, S0p, N0p),
)


valency = (
   (S0w, S0rv),
   (S0p, S0rv),
   (S0w, S0lv),
   (S0p, S0lv),
   (N0w, N0lv),
   (N0p, N0lv),
)


zhang_unigrams = (
   (S0hw,),
   (S0hp,),
   (S0lw,),
   (S0lp,),
   (S0rw,),
   (S0rp,),
   (N0lw,),
   (N0lp,),
)


third_order = (
   (S0h2w,),
   (S0h2p,),
   (S0l2w,),
   (S0l2p,),
   (S0r2w,),
   (S0r2p,),
   (N0l2w,),
   (N0l2p,),
   (S0p, S0lp, S0l2p),
   (S0p, S0rp, S0r2p),
   (S0p, S0hp, S0h2p),
   (N0p, N0lp, N0l2p)
)


labels = (
   (S0l,),
   (S0ll,),
   (S0rl,),
   (N0ll,),
   (S0hl,),
   (S0l2l,),
   (S0r2l,),
   (N0l2l,),
)


label_sets = (
   (S0w, S0rlabs),
   (S0p, S0rlabs),
   (S0w, S0llabs),
   (S0p, S0llabs),
   (N0w, N0llabs),
   (N0p, N0llabs),
)

extra_labels = (
    (S0p, S0ll, S0lp),
    (S0p, S0ll, S0l2l),
    (S0p, S0rl, S0rp),
    (S0p, S0rl, S0r2l),
    (S0p, S0ll, S0rl),
    (S0p, S0ll, S0l2l, S0l0l),
    (S0p, S0rl, S0r2l, S0r0l),
    (S0hp, S0l, S0rl),
    (S0hp, S0l, S0ll),
)

edges = (
    (S0re_w,),
    (S0re_p,),
    (S0re_w, S0re_p),
    (S0le_w,),
    (S0le_p,),
    (S0le_w, S0le_p),
    (N0le_w,),
    (N0le_p,),
    (N0le_w, N0le_p),
    (S0re_p, N0p,),
    (S0p, N0le_p)
)


stack_second = (
    (S1w,),
    (S1p,),
    (S1w, S1p),
    (S1w, N0w),
    (S1w, N0p),
    (S1p, N0w),
    (S1p, N0p),
    #(S1w, N1w),
    (S1w, N1p),
    (S1p, N1p),
    (S1p, N1w),
    (S1p, S0p, N0p),
    #(S1w, S0w, N0w),
    (S1w, S0p, N0p),
    #(S2w, N0w),
    #(S2w, N1w),
    (S2p, N0p, N1w),
    #(S2p, N0w, N1w),
    (S2w, N0p, N1p),
)

# Koo et al (2008) dependency features, using Brown clusters.
clusters = (
    # Koo et al have (head, child) --- we have S0, N0 for both.
    (S0c4, N0c4),
    (S0c6, N0c6),
    (S0c, N0c),
    (S0p, N0c4),
    (S0p, N0c6),
    (S0p, N0c),
    (S0c4, N0p),
    (S0c6, N0p),
    (S0c, N0p),
    # Siblings --- right arc
    (S0c4, S0rc4, N0c4),
    (S0c6, S0rc6, N0c6),
    (S0p, S0rc4, N0c4),
    (S0c4, S0rp, N0c4),
    (S0c4, S0rc4, N0p),
    # Siblings --- left arc
    (S0c4, N0lc4, N0c4),
    (S0c6, N0c6, N0c6),
    (S0c4, N0lc4, N0p),
    (S0c4, N0lp, N0c4),
    (S0p, N0lc4, N0c4),
    # Grand-child, right-arc
    (S0hc4, S0c4, N0c4),
    (S0hc6, S0c6, N0c6),
    (S0hp, S0c4, N0c4),
    (S0hc4, S0p, N0c4),
    (S0hc4, S0c4, N0p),
    # Grand-child, left-arc
    (S0lc4, S0c4, N0c4),
    (S0lc6, S0c6, N0c6),
    (S0lp, S0c4, N0c4),
    (S0lc4, S0p, N0c4),
    (S0lc4, S0c4, N0p)
)


disfl = (
    (prev_edit,),
    (prev_prev_edit,),
    (prev_edit_wmatch,),
    (prev_edit_pmatch,),
    (prev_edit_word,),
    (prev_edit_pos,),
    (wcopy,),
    (pcopy,),
    (wexact,),
    (pexact,),
    (wcopy, pcopy),
    (wexact, pexact),
    (wexact, pcopy),
    (wcopy, pexact),
    (prev_edit, wcopy),
    (prev_prev_edit, wcopy),
    (prev_edit, pcopy),
    (prev_prev_edit, pcopy)
)


# After emailing Mark after ACL
new_disfl = (
    (next_edit,),
    (next_next_edit,),
    (next_edit_wmatch,),
    (next_edit_pmatch,),
    (next_edit_word,),
    (next_edit_pos,),
    (next_edit, wcopy),
    (next_next_edit, wcopy),
    (next_edit, pcopy),
    (next_next_edit, pcopy),
)

suffix_disfl = (
    (wscopy,),
    (pscopy,),
    (wsexact,),
    (psexact,),
    (wscopy, pscopy),
    (wsexact, psexact),
    (wsexact, pscopy),
    (wscopy, psexact),
)


def pos_bigrams():
    kernels = [S2w, S1w, S0w, S0lw, S0rw, N0w, N0lw, N1w]
    bitags = []
    for t1, t2 in combinations(kernels, 2):
        feat = (t1 + 1, t2 + 1)
        bitags.append(feat)
    print "Adding %d bitags" % len(bitags)
    return tuple(bitags)


def baseline_templates():
    return from_single + from_word_pairs + from_three_words + distance + \
           valency + zhang_unigrams + third_order + labels + label_sets


def match_templates():
    match_feats = []
    kernel_tokens = get_kernel_tokens()
    for w1, w2 in combinations(kernel_tokens, 2):
        # Words match
        match_feats.append((w1, w2))
        # POS match
        match_feats.append((w1 + 1, w2 + 1))
    return tuple(match_feats)
